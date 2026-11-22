import 'dart:async';

import 'package:dlss_updater/src/data/daemon_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import 'support/fake_daemon_api.dart';

void main() {
  test('fake serves protocol messages through the DaemonApi seam', () async {
    final game = Game(
      id: 'game-1',
      appId: 42,
      name: 'Fixture Game',
      installPath: '/steam/steamapps/common/Fixture',
      libraryPath: '/steam',
      dlls: [
        GameDLL(
          id: 'dll-1',
          gameId: 'game-1',
          dllType: 'dlss',
          filename: 'nvngx_dlss.dll',
          path: '/steam/steamapps/common/Fixture/nvngx_dlss.dll',
          currentVersion: '2.4.2.0',
          sourceVersion: '3.7.10.0',
          exists: true,
        ),
      ],
    );
    final fake = FakeDaemonApi()
      ..status = Status(
        protoVersion: 'dlss.v1',
        appVersion: '0.1.0-dev.0',
        pid: 4242,
      )
      ..listGamesResponse = ListGamesResponse(games: [game])
      ..scanEvents = [
        ScanEvent(started: ScanStarted(steamRoot: '/steam')),
        ScanEvent(
          finished: ScanFinished(
            gameCount: 1,
            dllCount: 1,
            durationMs: Int64(12),
          ),
        ),
      ];
    final DaemonApi api = fake;

    final status = await api.getStatus(GetStatusRequest());
    expect(status.protoVersion, 'dlss.v1');
    expect(fake.getStatusRequests, hasLength(1));

    final library = await api.listGames(ListGamesRequest());
    expect(library.games.single.dlls.single.sourceVersion, '3.7.10.0');

    final scan = api.startScan(StartScanRequest(steamRoot: '/steam'));
    final events = await scan.events.toList();
    expect(fake.startScanRequests.single.steamRoot, '/steam');
    expect(events.first.started.steamRoot, '/steam');
    expect(events.last.finished.cancelled, isFalse);
  });

  test('fake scan stream can be cancelled and errors carry reasons', () async {
    final controller = StreamController<ScanEvent>();
    final fake = FakeDaemonApi()..scanController = controller;
    final api = fake;

    final scan = api.startScan(StartScanRequest(steamRoot: '/steam'));
    final received = <ScanEvent>[];
    scan.events.listen(received.add);
    controller.add(ScanEvent(started: ScanStarted(steamRoot: '/steam')));
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));

    await scan.cancel();
    expect(fake.scanCancelled, isTrue);
    expect(controller.isClosed, isTrue);

    final failing = FakeDaemonApi()
      ..getStatusError = grpcErrorForReason(
        'ALREADY_RUNNING',
        message: 'Another instance is running.',
        code: StatusCode.failedPrecondition,
      );
    await expectLater(
      failing.getStatus(GetStatusRequest()),
      throwsA(
        isA<GrpcError>()
            .having(
              (error) => error.code,
              'code',
              StatusCode.failedPrecondition,
            )
            .having((error) => error.details, 'details', isNotEmpty),
      ),
    );
  });
}
