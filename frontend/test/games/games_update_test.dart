import 'dart:async';

import 'package:dlss_updater/src/data/daemon_api.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/ui/games/widgets/update_keys.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_daemon_api.dart';
import 'games_view_test.dart';

GameDLL dll({
  required String id,
  required String filename,
  String type = 'dlss',
  String currentVersion = '2.4.2.0',
  String sourceVersion = '3.7.10.0',
}) {
  return GameDLL(
    id: id,
    gameId: 'game-1',
    dllType: type,
    filename: filename,
    path: '/steam/steamapps/common/Fixture/$filename',
    currentVersion: currentVersion,
    sourceVersion: sourceVersion,
    exists: true,
  );
}

List<GameDLL> twoDlls() => [
  dll(id: 'dll-1', filename: 'nvngx_dlss.dll'),
  dll(
    id: 'dll-2',
    filename: 'nvngx_dlssg.dll',
    type: 'dlss_g',
    currentVersion: '1.0.0.0',
  ),
];

UpdateEvent updateStarted({int itemCount = 2}) {
  return UpdateEvent(started: UpdateStarted(itemCount: itemCount));
}

UpdateEvent itemStarted(
  String dllId,
  String filename, {
  int index = 1,
  int total = 2,
}) {
  return UpdateEvent(
    itemStarted: UpdateItemStarted(
      dllId: dllId,
      filename: filename,
      index: index,
      total: total,
    ),
  );
}

UpdateEvent itemFinished(
  String dllId, {
  UpdateOutcome outcome = UpdateOutcome.UPDATE_OUTCOME_UPDATED,
  String reason = '',
  String resultingVersion = '3.7.10.0',
}) {
  return UpdateEvent(
    itemFinished: UpdateItemFinished(
      dllId: dllId,
      outcome: outcome,
      reason: reason,
      resultingVersion: resultingVersion,
      durationMs: Int64(100),
    ),
  );
}

UpdateEvent updateFinished({
  int succeeded = 2,
  int skipped = 0,
  int failed = 0,
  bool cancelled = false,
  int durationMs = 1200,
}) {
  return UpdateEvent(
    finished: UpdateFinished(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
      cancelled: cancelled,
      durationMs: Int64(durationMs),
    ),
  );
}

Future<GamesHarness> pumpGames(
  WidgetTester tester, {
  List<GameDLL>? dlls,
}) async {
  final harness = GamesHarness();
  addTearDown(harness.dispose);
  final game = gameWith(dlls: dlls ?? twoDlls());
  harness.api.listGamesResponse = ListGamesResponse(games: [game]);
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('game-game-1')));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> selectDll(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('dll-select-$id')));
  await tester.pump();
}

bool updateButtonEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byKey(UpdateKeys.selected));
  return button.onPressed != null;
}

bool rowUpdateEnabled(WidgetTester tester, String id) {
  final button = tester.widget<IconButton>(find.byKey(Key('dll-update-$id')));
  return button.onPressed != null;
}

Future<void> startSelectedUpdate(WidgetTester tester) async {
  await tester.tap(find.byKey(UpdateKeys.selected));
  await tester.pump();
}

class ErrorCase {
  const ErrorCase(this.reason, this.snippet, this.retryLabel);

  final String reason;
  final String snippet;
  final String retryLabel;
}

class ReasonCase {
  const ReasonCase(
    this.reason,
    this.outcome,
    this.snippet, {
    this.updated = false,
  });

  final String reason;
  final UpdateOutcome outcome;
  final String snippet;
  final bool updated;
}

void main() {
  testWidgets('selection enables the update action and sends selected ids', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;

    expect(updateButtonEnabled(tester), isFalse);

    await selectDll(tester, 'dll-1');
    await selectDll(tester, 'dll-2');
    expect(updateButtonEnabled(tester), isTrue);

    await startSelectedUpdate(tester);
    expect(harness.api.startUpdateRequests, hasLength(1));
    expect(harness.api.startUpdateRequests.single.dllIds, ['dll-1', 'dll-2']);

    controller.add(updateStarted());
    controller.add(itemStarted('dll-1', 'nvngx_dlss.dll', index: 1, total: 2));
    await tester.pump();

    expect(find.byKey(UpdateKeys.progress), findsOneWidget);
    expect(find.text('Updating DLLs'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('nvngx_dlss.dll'), findsWidgets);
    expect(find.byKey(UpdateKeys.cancel), findsOneWidget);
  });

  testWidgets('multiple items progress, finish and show counts with reasons', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;
    harness.api.game = gameWith(
      dlls: [
        dll(
          id: 'dll-1',
          filename: 'nvngx_dlss.dll',
          currentVersion: '3.7.10.0',
        ),
        dll(
          id: 'dll-2',
          filename: 'nvngx_dlssg.dll',
          type: 'dlss_g',
          currentVersion: '2.0.0.0',
        ),
      ],
    );

    await selectDll(tester, 'dll-1');
    await selectDll(tester, 'dll-2');
    await startSelectedUpdate(tester);

    controller.add(updateStarted());
    controller.add(itemStarted('dll-1', 'nvngx_dlss.dll', index: 1, total: 2));
    controller.add(itemFinished('dll-1'));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Updated'), findsWidgets);

    controller.add(itemStarted('dll-2', 'nvngx_dlssg.dll', index: 2, total: 2));
    await tester.pump();
    expect(find.text('nvngx_dlssg.dll'), findsWidgets);

    controller.add(
      itemFinished(
        'dll-2',
        outcome: UpdateOutcome.UPDATE_OUTCOME_SKIPPED,
        reason: 'BELOW_MINIMUM',
      ),
    );
    controller.add(updateFinished(succeeded: 1, skipped: 1, failed: 0));
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateKeys.progress), findsNothing);
    expect(find.byKey(UpdateKeys.summary), findsOneWidget);
    expect(find.byKey(UpdateKeys.dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Update complete'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.textContaining('1 updated · 1 skipped · 0 failed'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Duration: 1.2 s'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(UpdateKeys.dialogItems));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Updated'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Skipped: below the minimum supported version'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(UpdateKeys.dialogClose));
    await tester.pumpAndSettle();

    expect(harness.api.getGameRequests, isNotEmpty);
    expect(harness.api.getGameRequests.last.gameId, 'game-1');
    expect(find.text('Current 3.7.10.0'), findsOneWidget);

    await tester.tap(find.byKey(UpdateKeys.summaryDetails));
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateKeys.dialog), findsOneWidget);
  });

  testWidgets('cancelling keeps finished results and shows a local summary', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;

    await selectDll(tester, 'dll-1');
    await selectDll(tester, 'dll-2');
    await startSelectedUpdate(tester);

    controller.add(updateStarted());
    controller.add(itemStarted('dll-1', 'nvngx_dlss.dll', index: 1, total: 2));
    controller.add(itemFinished('dll-1'));
    await tester.pump();

    await tester.tap(find.byKey(UpdateKeys.cancel));
    await tester.pump();

    expect(harness.api.updateCancelled, isTrue);
    expect(find.byKey(UpdateKeys.progress), findsNothing);
    expect(find.byKey(UpdateKeys.failure), findsNothing);
    expect(find.byKey(UpdateKeys.summary), findsOneWidget);
    expect(find.text('Update cancelled'), findsWidgets);
    expect(updateButtonEnabled(tester), isTrue);
    expect(harness.api.getGameRequests, isNotEmpty);

    await tester.pumpAndSettle();
    expect(find.byKey(UpdateKeys.dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.textContaining('1 updated · 0 skipped · 0 failed'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(UpdateKeys.dialogItems));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Updated'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.dialog),
        matching: find.text('Cancelled'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a row-level action updates exactly that DLL', (tester) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;

    await tester.tap(find.byKey(const Key('dll-update-dll-2')));
    await tester.pump();

    expect(harness.api.startUpdateRequests, hasLength(1));
    expect(harness.api.startUpdateRequests.single.dllIds, ['dll-2']);
  });

  testWidgets('the update action is disabled while a run is active', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    controller.add(updateStarted(itemCount: 1));
    await tester.pump();

    expect(updateButtonEnabled(tester), isFalse);
    expect(rowUpdateEnabled(tester, 'dll-1'), isFalse);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('dll-select-dll-1')))
          .onChanged,
      isNull,
    );
    expect(find.byKey(UpdateKeys.cancel), findsOneWidget);
  });

  testWidgets('the update action is disabled while the daemon is unavailable', (
    tester,
  ) async {
    final harness = await pumpGames(tester);

    await selectDll(tester, 'dll-1');
    expect(updateButtonEnabled(tester), isTrue);

    harness.connection.setStatus(DaemonConnectionStatus.unavailable);
    await tester.pump();

    expect(updateButtonEnabled(tester), isFalse);
    expect(rowUpdateEnabled(tester, 'dll-1'), isFalse);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('dll-select-dll-1')))
          .onChanged,
      isNull,
    );

    harness.connection.setStatus(DaemonConnectionStatus.connected);
    await tester.pump();
    expect(updateButtonEnabled(tester), isTrue);
  });

  const errorCases = [
    ErrorCase(
      'UPDATE_IN_PROGRESS',
      'Another update is already running',
      'Try again',
    ),
    ErrorCase(
      'SOURCE_MISSING',
      'The DLL source folder is missing',
      'Choose folder',
    ),
    ErrorCase(
      'METADATA_STALE',
      'stored library data is out of date',
      'Scan again',
    ),
  ];

  for (final errorCase in errorCases) {
    testWidgets('run error ${errorCase.reason} shows an actionable message', (
      tester,
    ) async {
      final harness = await pumpGames(tester);
      harness.api.startUpdateError = grpcErrorForReason(
        errorCase.reason,
        message: 'server detail',
      );

      await selectDll(tester, 'dll-1');
      await startSelectedUpdate(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(UpdateKeys.failure), findsOneWidget);
      expect(find.textContaining(errorCase.snippet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(UpdateKeys.failure),
          matching: find.text(errorCase.retryLabel),
        ),
        findsOneWidget,
      );
      expect(find.byKey(UpdateKeys.summary), findsNothing);
      expect(find.byKey(UpdateKeys.dialog), findsNothing);
    });
  }

  testWidgets('a daemon-unavailable run error offers a reconnect retry', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    harness.api.startUpdateError = grpcErrorForReason(
      'INTERNAL',
      message: 'daemon is down',
      code: StatusCode.unavailable,
    );

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('The daemon is not reachable'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(UpdateKeys.failure),
        matching: find.text('Retry'),
      ),
      findsOneWidget,
    );

    harness.api.startUpdateError = null;
    harness.api.updateEvents = [
      updateStarted(itemCount: 1),
      itemFinished('dll-1'),
      updateFinished(succeeded: 1),
    ];
    await tester.tap(find.byKey(UpdateKeys.retry));
    await tester.pumpAndSettle();

    expect(harness.connection.retryCalls, 1);
    expect(harness.api.startUpdateRequests, hasLength(2));
    expect(find.byKey(UpdateKeys.dialog), findsOneWidget);
  });

  testWidgets('retrying UPDATE_IN_PROGRESS starts the selected update again', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    harness.api.startUpdateError = grpcErrorForReason('UPDATE_IN_PROGRESS');

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateKeys.failure), findsOneWidget);

    harness.api.startUpdateError = null;
    harness.api.updateEvents = [
      updateStarted(itemCount: 1),
      itemFinished('dll-1'),
      updateFinished(succeeded: 1),
    ];
    await tester.tap(find.byKey(UpdateKeys.retry));
    await tester.pumpAndSettle();

    expect(harness.api.startUpdateRequests, hasLength(2));
    expect(harness.api.startUpdateRequests.last.dllIds, ['dll-1']);
    expect(find.byKey(UpdateKeys.summary), findsOneWidget);
  });

  testWidgets('closing a run error returns the detail to its normal state', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    harness.api.startUpdateError = grpcErrorForReason('UPDATE_IN_PROGRESS');

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateKeys.failure), findsOneWidget);

    await tester.tap(find.byKey(UpdateKeys.dismiss));
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateKeys.failure), findsNothing);
    expect(updateButtonEnabled(tester), isTrue);
  });

  testWidgets('a failed event becomes a run-level error, not a summary', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    final controller = StreamController<UpdateEvent>();
    harness.api.updateController = controller;

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    controller.add(updateStarted(itemCount: 1));
    controller.add(
      UpdateEvent(
        failed: UpdateFailed(
          reason: 'SOURCE_MISSING',
          message: 'source folder is empty',
        ),
      ),
    );
    await controller.close();
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateKeys.failure), findsOneWidget);
    expect(
      find.textContaining('The DLL source folder is missing'),
      findsOneWidget,
    );
    expect(find.byKey(UpdateKeys.summary), findsNothing);
    expect(find.byKey(UpdateKeys.dialog), findsNothing);
  });

  testWidgets('a stream without finished ends in an error state', (
    tester,
  ) async {
    final harness = await pumpGames(tester);
    harness.api.updateEvents = [
      updateStarted(itemCount: 1),
      itemStarted('dll-1', 'nvngx_dlss.dll', total: 1),
      itemFinished('dll-1'),
    ];

    await selectDll(tester, 'dll-1');
    await startSelectedUpdate(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateKeys.failure), findsOneWidget);
    expect(find.textContaining('ended unexpectedly'), findsOneWidget);
    expect(find.byKey(UpdateKeys.summary), findsNothing);
    expect(find.byKey(UpdateKeys.dialog), findsNothing);
  });

  const reasonCases = [
    ReasonCase(
      '',
      UpdateOutcome.UPDATE_OUTCOME_UPDATED,
      'Updated',
      updated: true,
    ),
    ReasonCase(
      'UP_TO_DATE',
      UpdateOutcome.UPDATE_OUTCOME_SKIPPED,
      'Already up to date',
    ),
    ReasonCase(
      'BELOW_MINIMUM',
      UpdateOutcome.UPDATE_OUTCOME_SKIPPED,
      'Skipped: below the minimum supported version',
    ),
    ReasonCase(
      'TARGET_MISSING',
      UpdateOutcome.UPDATE_OUTCOME_SKIPPED,
      'Skipped: the target file is missing',
    ),
    ReasonCase(
      'SOURCE_MISSING',
      UpdateOutcome.UPDATE_OUTCOME_SKIPPED,
      'Skipped: no source file is available',
    ),
    ReasonCase(
      'PERMISSION_DENIED',
      UpdateOutcome.UPDATE_OUTCOME_FAILED,
      'Failed: permission denied',
    ),
    ReasonCase(
      'VERSION_MISMATCH',
      UpdateOutcome.UPDATE_OUTCOME_FAILED,
      'Rolled back: the copied file did not match the source version',
    ),
    ReasonCase(
      'METADATA_STALE',
      UpdateOutcome.UPDATE_OUTCOME_FAILED,
      'Updated on disk; the stored version could not be saved',
    ),
    ReasonCase('CANCELLED', UpdateOutcome.UPDATE_OUTCOME_SKIPPED, 'Cancelled'),
    ReasonCase(
      'INTERNAL',
      UpdateOutcome.UPDATE_OUTCOME_FAILED,
      'Failed: internal error',
    ),
  ];

  for (final reasonCase in reasonCases) {
    final name = reasonCase.reason.isEmpty ? 'updated' : reasonCase.reason;
    testWidgets('item result $name renders its own message', (tester) async {
      final harness = await pumpGames(tester);
      harness.api.updateEvents = [
        updateStarted(itemCount: 1),
        itemFinished(
          'dll-1',
          outcome: reasonCase.outcome,
          reason: reasonCase.reason,
        ),
        updateFinished(
          succeeded: reasonCase.updated ? 1 : 0,
          skipped: reasonCase.outcome == UpdateOutcome.UPDATE_OUTCOME_SKIPPED
              ? 1
              : 0,
          failed: reasonCase.outcome == UpdateOutcome.UPDATE_OUTCOME_FAILED
              ? 1
              : 0,
        ),
      ];

      await selectDll(tester, 'dll-1');
      await startSelectedUpdate(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(UpdateKeys.dialog), findsOneWidget);
      await tester.tap(find.byKey(UpdateKeys.dialogItems));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(UpdateKeys.dialog),
          matching: find.text(reasonCase.snippet),
        ),
        findsOneWidget,
      );
    });
  }
}
