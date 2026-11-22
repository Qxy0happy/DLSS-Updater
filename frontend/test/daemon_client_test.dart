import 'dart:io';

import 'package:dlss_updater/src/data/daemon_api.dart' show Status;
import 'package:dlss_updater/src/data/daemon_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'support/fake_daemon_api.dart';
import 'support/fake_daemon_process.dart';

DaemonClientConfig config({
  String dataDir = '/tmp/dlss-data',
  String socketPath = '/tmp/dlss-run/daemon.sock',
  String dllSourceDir = '/tmp/dlss-source',
  String executable = '/usr/bin/dlssd',
}) {
  return DaemonClientConfig(
    dataDir: dataDir,
    socketPath: socketPath,
    dllSourceDir: dllSourceDir,
    executable: executable,
  );
}

DaemonClient buildClient(
  FakeDaemonApi api,
  FakeProcessStarter starter, {
  DaemonClientConfig? clientConfig,
}) {
  return DaemonClient(
    config: clientConfig ?? config(),
    processStarter: starter.start,
    api: api,
    exitGrace: const Duration(milliseconds: 5),
    handshakeTimeout: const Duration(milliseconds: 20),
    handshakePoll: const Duration(milliseconds: 1),
  );
}

void main() {
  test('spawns dlssd with all three explicit paths and handshakes', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.2.3');
    final starter = FakeProcessStarter();
    final client = buildClient(api, starter);

    final handshake = await client.start();

    expect(handshake.appVersion, '1.2.3');
    expect(handshake.protoVersion, 'dlss.v1');
    expect(starter.calls.single, <String>[
      '/usr/bin/dlssd',
      '--data-dir',
      '/tmp/dlss-data',
      '--socket',
      '/tmp/dlss-run/daemon.sock',
      '--dll-source-dir',
      '/tmp/dlss-source',
    ]);
    await client.shutdown();
  });

  test('rejects a daemon that speaks another proto version', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v2', appVersion: '9.9.9');
    final starter = FakeProcessStarter();
    final client = buildClient(api, starter);

    await expectLater(client.start(), throwsA(isA<DaemonConfigException>()));
    await client.shutdown();
  });

  test('asks the daemon to shut down before signalling', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.0.0');
    final starter = FakeProcessStarter();
    final client = buildClient(api, starter);
    await client.start();

    await client.shutdown();

    expect(api.shutdownRequests, hasLength(1));
    expect(starter.processes.single.signals, contains(ProcessSignal.sigterm));
    expect(api.closed, isTrue);
  });

  test('survives a daemon that ignores the shutdown RPC', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.0.0')
      ..shutdownError = const SocketException('connection reset');
    final starter = FakeProcessStarter();
    final client = buildClient(api, starter);
    await client.start();

    await client.shutdown();

    expect(starter.processes.single.signals, contains(ProcessSignal.sigterm));
    expect(api.closed, isTrue);
  });

  test('restart passes the new DLL source directory', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.0.0');
    final starter = FakeProcessStarter();
    final client = buildClient(api, starter);
    await client.start();

    client.config = client.config.copyWith(dllSourceDir: '/new/source');
    await client.restart();

    expect(starter.calls, hasLength(2));
    expect(
      starter.calls.last,
      containsAllInOrder(<String>['--dll-source-dir', '/new/source']),
    );
    await client.shutdown();
  });

  test('missing binary is a configuration error', () async {
    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.0.0');
    final starter = FakeProcessStarter()
      ..error = const ProcessException('dlssd', <String>[], 'No such file', 2);
    final client = buildClient(api, starter);

    await expectLater(client.start(), throwsA(isA<DaemonConfigException>()));
  });

  test('shutdown never deletes a regular file at the socket path', () async {
    final dir = Directory.systemTemp.createTempSync('dlss-client-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final socket = '${dir.path}/daemon.sock';
    final file = File(socket)..writeAsStringSync('not a socket');

    final api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.0.0');
    final client = buildClient(
      api,
      FakeProcessStarter(),
      clientConfig: config(socketPath: socket),
    );
    await client.start();

    await client.shutdown();

    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), 'not a socket');
  });

  test('isDaemonUnavailable maps transient gRPC codes only', () {
    expect(isDaemonUnavailable(GrpcError.unavailable('down')), isTrue);
    expect(
      isDaemonUnavailable(GrpcError.custom(StatusCode.unknown, 'gone')),
      isTrue,
    );
    expect(isDaemonUnavailable(GrpcError.deadlineExceeded('slow')), isTrue);
    expect(isDaemonUnavailable(GrpcError.notFound('missing')), isFalse);
    expect(isDaemonUnavailable(StateError('local')), isFalse);
  });
}
