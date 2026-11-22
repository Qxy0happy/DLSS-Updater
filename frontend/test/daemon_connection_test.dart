import 'dart:ui' show AppExitResponse;

import 'package:dlss_updater/src/app_exit.dart';
import 'package:dlss_updater/src/data/daemon_api.dart' show Status;
import 'package:dlss_updater/src/data/daemon_client.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'support/fake_daemon_api.dart';
import 'support/fake_daemon_process.dart';

DaemonClientConfig _config() => const DaemonClientConfig(
  dataDir: '/tmp/dlss-data',
  socketPath: '/tmp/dlss-run/daemon.sock',
  dllSourceDir: '/tmp/dlss-source',
  executable: '/usr/bin/dlssd',
);

class Harness {
  Harness({int maxAttempts = 5, Duration Function(int)? backoff})
    : api = FakeDaemonApi()
        ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.2.3'),
      starter = FakeProcessStarter() {
    client = DaemonClient(
      config: _config(),
      processStarter: starter.start,
      api: api,
      exitGrace: const Duration(milliseconds: 5),
      handshakeTimeout: const Duration(milliseconds: 2),
      handshakePoll: const Duration(milliseconds: 1),
    );
    controller = DaemonController(
      client: client,
      backoff: backoff ?? (_) => Duration.zero,
      maxAttempts: maxAttempts,
    );
  }

  final FakeDaemonApi api;
  final FakeProcessStarter starter;
  late final DaemonClient client;
  late final DaemonController controller;
}

Future<void> pumpUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition was not met in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('is starting until the handshake succeeds', () async {
    final harness = Harness();
    expect(harness.controller.status, DaemonConnectionStatus.starting);

    await harness.controller.start();

    expect(harness.controller.status, DaemonConnectionStatus.connected);
    expect(harness.controller.daemonVersion, '1.2.3');
    expect(harness.controller.protoVersion, 'dlss.v1');
    expect(harness.controller.lastError, isNull);
    await harness.controller.shutdown();
  });

  test('transient failures reconnect with backoff', () async {
    final harness = Harness(backoff: (_) => const Duration(milliseconds: 5));
    harness.api.getStatusError = GrpcError.unavailable('daemon down');

    await harness.controller.start();
    expect(harness.controller.status, DaemonConnectionStatus.reconnecting);

    harness.api.getStatusError = null;
    await pumpUntil(
      () => harness.controller.status == DaemonConnectionStatus.connected,
    );
    expect(harness.starter.calls.length, greaterThan(1));
    await harness.controller.shutdown();
  });

  test('proto mismatch is surfaced without a restart loop', () async {
    final harness = Harness();
    harness.api.status = Status(protoVersion: 'dlss.v2', appVersion: '9.9.9');

    await harness.controller.start();

    expect(harness.controller.status, DaemonConnectionStatus.unavailable);
    expect(harness.controller.lastError, contains('dlss.v2'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.starter.calls, hasLength(1));
    expect(harness.controller.status, DaemonConnectionStatus.unavailable);
  });

  test('a crashed daemon is respawned', () async {
    final harness = Harness();
    await harness.controller.start();
    expect(harness.starter.processes, hasLength(1));

    harness.starter.processes.single.exit(1);

    await pumpUntil(() => harness.starter.processes.length == 2);
    await pumpUntil(
      () => harness.controller.status == DaemonConnectionStatus.connected,
    );
    expect(harness.controller.lastError, isNull);
    await harness.controller.shutdown();
  });

  test('manual retry resets an exhausted restart budget', () async {
    final harness = Harness(maxAttempts: 1);
    harness.api.getStatusError = GrpcError.unavailable('daemon down');

    await harness.controller.start();
    await pumpUntil(
      () => harness.controller.status == DaemonConnectionStatus.unavailable,
    );
    expect(harness.controller.lastError, contains('Automatic restart stopped'));

    harness.api.getStatusError = null;
    await harness.controller.retry();

    expect(harness.controller.status, DaemonConnectionStatus.connected);
    await harness.controller.shutdown();
  });

  test('app exit shuts the daemon down before leaving', () async {
    final harness = Harness();
    await harness.controller.start();
    final handler = AppExitHandler(harness.controller);

    final response = await handler.onExitRequested();

    expect(response, AppExitResponse.exit);
    expect(harness.api.shutdownRequests, hasLength(1));
    expect(harness.controller.status, DaemonConnectionStatus.unavailable);
  });

  test('restartWithDllSource updates the visible source directory', () async {
    final harness = Harness();
    await harness.controller.start();

    await harness.controller.restartWithDllSource('/tmp/other-source');

    expect(harness.controller.dllSourceDir, '/tmp/other-source');
    expect(harness.controller.status, DaemonConnectionStatus.connected);
    expect(
      harness.starter.calls.last,
      containsAllInOrder(<String>['--dll-source-dir', '/tmp/other-source']),
    );
    await harness.controller.shutdown();
  });
}
