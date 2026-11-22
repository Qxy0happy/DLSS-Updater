import 'dart:async';

import 'package:dlss_updater/src/data/daemon_api.dart';
import 'package:dlss_updater/src/ui/backups/backups_view.dart';
import 'package:dlss_updater/src/ui/backups/models.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    show Timestamp;

import '../support/fake_daemon_api.dart';

/// Serves a queue of list responses so a test can observe the requery after a
/// restore or delete, including the `include_inactive` flag.
class ScriptedBackupsApi extends FakeDaemonApi {
  ScriptedBackupsApi([List<ListBackupsResponse>? responses])
    : responses = responses ?? <ListBackupsResponse>[];

  final List<ListBackupsResponse> responses;

  @override
  Future<ListBackupsResponse> listBackups(ListBackupsRequest request) async {
    listBackupsRequests.add(request);
    final error = listBackupsError;
    if (error != null) throw error;
    if (responses.isEmpty) return ListBackupsResponse();
    return responses.removeAt(0);
  }
}

class PendingBackupsApi extends FakeDaemonApi {
  final Completer<ListBackupsResponse> pending =
      Completer<ListBackupsResponse>();

  @override
  Future<ListBackupsResponse> listBackups(ListBackupsRequest request) {
    listBackupsRequests.add(request);
    return pending.future;
  }
}

BackupRecord backupRecord({
  String id = 'backup-1',
  String gameId = 'game-1',
  String gameName = 'Elden Ring',
  String dllFilename = 'nvngx_dlss.dll',
  String dllType = 'dlss',
  String backupPath = '/games/Elden Ring/nvngx_dlss.dlsss',
  String originalVersion = '2.4.12',
  int sizeBytes = 1536,
  DateTime? createdAt,
  bool isActive = true,
  bool targetExists = true,
  DateTime? restoredAt,
}) {
  return BackupRecord(
    id: id,
    gameId: gameId,
    dllId: 'dll-$id',
    gameName: gameName,
    dllFilename: dllFilename,
    dllType: dllType,
    backupPath: backupPath,
    originalVersion: originalVersion,
    sizeBytes: Int64(sizeBytes),
    createdAt: Timestamp.fromDateTime(
      createdAt ?? DateTime.utc(2026, 1, 2, 15, 4),
    ),
    isActive: isActive,
    restoredAt: restoredAt == null ? null : Timestamp.fromDateTime(restoredAt),
    targetExists: targetExists,
  );
}

ListBackupsResponse backups(List<BackupRecord> records) =>
    ListBackupsResponse(backups: records);

class BackupsHarness {
  BackupsHarness([List<ListBackupsResponse>? responses])
    : api = ScriptedBackupsApi(responses);

  final ScriptedBackupsApi api;

  Widget build() {
    return Provider<DaemonApi>.value(
      value: api,
      child: const MaterialApp(home: Scaffold(body: BackupsView())),
    );
  }
}

Future<void> pumpBackups(WidgetTester tester, BackupsHarness harness) async {
  await tester.pumpWidget(harness.build());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('groups active backups by game and shows row metadata', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([
        backupRecord(),
        backupRecord(
          id: 'backup-2',
          gameId: 'game-2',
          gameName: 'Cyberpunk 2077',
          dllFilename: 'libxess.dll',
          dllType: 'xess',
          backupPath: '/games/Cyberpunk 2077/libxess.dlsss',
          originalVersion: '1.3.0',
          sizeBytes: 2 * 1024 * 1024,
          createdAt: DateTime.utc(2026, 2, 3, 9, 30),
        ),
      ]),
    ]);
    await pumpBackups(tester, harness);

    expect(harness.api.listBackupsRequests.single.includeInactive, isFalse);

    expect(find.text('Elden Ring'), findsOneWidget);
    expect(find.text('Cyberpunk 2077'), findsOneWidget);
    expect(find.text('nvngx_dlss.dll'), findsOneWidget);
    expect(find.text('libxess.dll'), findsOneWidget);
    expect(find.text('DLSS'), findsOneWidget);
    expect(find.text('XeSS'), findsOneWidget);
    expect(find.text('2.4.12'), findsOneWidget);
    expect(find.text('1.3.0'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(find.text('2026-01-02 15:04 UTC'), findsOneWidget);
    expect(find.text('2026-02-03 09:30 UTC'), findsOneWidget);
    expect(find.text('/games/Elden Ring/nvngx_dlss.dll'), findsOneWidget);
    expect(find.text('/games/Cyberpunk 2077/libxess.dll'), findsOneWidget);
  });

  testWidgets('orphaned backups get their own section and indicator', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([
        backupRecord(),
        backupRecord(
          id: 'backup-orphan',
          gameId: 'game-lost',
          gameName: 'Lost Game',
          targetExists: false,
        ),
      ]),
    ]);
    await pumpBackups(tester, harness);

    final orphanSection = find.byKey(BackupsView.orphanSectionKey);
    expect(orphanSection, findsOneWidget);
    expect(
      find.descendant(of: orphanSection, matching: find.text('Lost Game')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: orphanSection, matching: find.text('Orphan')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(BackupsView.activeSectionKey),
        matching: find.text('Lost Game'),
      ),
      findsNothing,
    );
  });

  testWidgets('shows the empty state when nothing is backed up', (
    tester,
  ) async {
    final harness = BackupsHarness([backups([])]);
    await pumpBackups(tester, harness);

    expect(find.byKey(BackupsView.emptyKey), findsOneWidget);
    expect(find.text(BackupsView.emptyTitle), findsOneWidget);
    expect(find.text(BackupsView.emptyMessage), findsOneWidget);
  });

  testWidgets('shows a loading state while the first query is pending', (
    tester,
  ) async {
    final api = PendingBackupsApi();
    await tester.pumpWidget(
      Provider<DaemonApi>.value(
        value: api,
        child: const MaterialApp(home: Scaffold(body: BackupsView())),
      ),
    );
    await tester.pump();

    expect(find.byKey(BackupsView.loadingKey), findsOneWidget);

    api.pending.complete(backups([]));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupsView.loadingKey), findsNothing);
    expect(find.text(BackupsView.emptyTitle), findsOneWidget);
  });

  testWidgets(
    'load failure maps the reason, ignores the status text, retries',
    (tester) async {
      final harness = BackupsHarness();
      harness.api.listBackupsError = grpcErrorForReason(
        'BACKUP_CORRUPT',
        message: 'raw server text',
      );
      await pumpBackups(tester, harness);

      expect(find.text('Could not load backups'), findsOneWidget);
      expect(find.text(BackupFailureCopy.backupCorrupt), findsOneWidget);
      expect(find.text('raw server text'), findsNothing);

      harness.api.listBackupsError = null;
      harness.api.responses.add(backups([backupRecord()]));
      await tester.tap(find.byKey(BackupsView.retryKey));
      await tester.pumpAndSettle();

      expect(find.text('nvngx_dlss.dll'), findsOneWidget);
      expect(find.byKey(BackupsView.loadErrorKey), findsNothing);
    },
  );

  testWidgets('restore waits for confirmation and cancel does nothing', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([backupRecord()]),
      backups([backupRecord(isActive: false)]),
    ]);
    await pumpBackups(tester, harness);

    await tester.tap(find.byKey(BackupsView.restoreButtonKey('backup-1')));
    await tester.pumpAndSettle();

    expect(find.text('Restore DLL backup?'), findsOneWidget);
    expect(find.textContaining('overwrites the current DLL'), findsOneWidget);
    expect(find.textContaining('safety copy'), findsOneWidget);
    expect(find.textContaining('original location'), findsNothing);

    await tester.tap(find.byKey(BackupsView.cancelRestoreKey));
    await tester.pumpAndSettle();

    expect(harness.api.restoreBackupRequests, isEmpty);
    expect(harness.api.listBackupsRequests, hasLength(1));
  });

  testWidgets('confirmed restore requeries history and moves the row', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([backupRecord()]),
      backups([
        backupRecord(isActive: false, restoredAt: DateTime.utc(2026, 1, 3, 10)),
      ]),
    ]);
    await pumpBackups(tester, harness);

    await tester.tap(find.byKey(BackupsView.restoreButtonKey('backup-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupsView.confirmRestoreKey));
    await tester.pumpAndSettle();

    expect(harness.api.restoreBackupRequests.single.backupId, 'backup-1');
    expect(harness.api.listBackupsRequests, hasLength(2));
    expect(harness.api.listBackupsRequests.last.includeInactive, isTrue);

    final history = find.byKey(BackupsView.historySectionKey);
    expect(history, findsOneWidget);
    expect(
      find.descendant(of: history, matching: find.text('nvngx_dlss.dll')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: history, matching: find.text('Restored')),
      findsOneWidget,
    );
    expect(find.text('Restored nvngx_dlss.dll.'), findsOneWidget);
    expect(find.byKey(BackupsView.activeSectionKey), findsNothing);
  });

  testWidgets('orphan restore confirmation explains the original location', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([backupRecord(targetExists: false)]),
    ]);
    await pumpBackups(tester, harness);

    await tester.tap(find.byKey(BackupsView.restoreButtonKey('backup-1')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('still installed at its original location'),
      findsOneWidget,
    );
  });

  testWidgets('delete waits for confirmation and refreshes after success', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([backupRecord()]),
      backups([]),
    ]);
    await pumpBackups(tester, harness);

    await tester.tap(find.byKey(BackupsView.deleteButtonKey('backup-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete backup?'), findsOneWidget);
    expect(find.textContaining('permanently deletes'), findsOneWidget);

    await tester.tap(find.byKey(BackupsView.cancelDeleteKey));
    await tester.pumpAndSettle();
    expect(harness.api.deleteBackupRequests, isEmpty);
    expect(harness.api.listBackupsRequests, hasLength(1));

    await tester.tap(find.byKey(BackupsView.deleteButtonKey('backup-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupsView.confirmDeleteKey));
    await tester.pumpAndSettle();

    expect(harness.api.deleteBackupRequests.single.backupId, 'backup-1');
    expect(harness.api.listBackupsRequests, hasLength(2));
    expect(find.byKey(BackupsView.emptyKey), findsOneWidget);
  });

  testWidgets('history toggle requeries inactive backups', (tester) async {
    final harness = BackupsHarness([
      backups([backupRecord()]),
      backups([
        backupRecord(),
        backupRecord(
          id: 'old',
          isActive: false,
          restoredAt: DateTime.utc(2026, 1, 3, 10),
        ),
      ]),
    ]);
    await pumpBackups(tester, harness);

    expect(find.byKey(BackupsView.historySectionKey), findsNothing);

    await tester.tap(find.byKey(BackupsView.historyToggleKey));
    await tester.pumpAndSettle();

    expect(harness.api.listBackupsRequests.last.includeInactive, isTrue);
    expect(find.byKey(BackupsView.historySectionKey), findsOneWidget);
    expect(find.text('Restored'), findsOneWidget);
  });

  testWidgets('daemon unavailable state is actionable and retryable', (
    tester,
  ) async {
    final harness = BackupsHarness();
    harness.api.listBackupsError = const GrpcError.unavailable('socket gone');
    await pumpBackups(tester, harness);

    expect(find.text('Daemon unavailable'), findsOneWidget);
    expect(find.text(BackupFailureCopy.daemonUnavailable), findsOneWidget);

    harness.api.listBackupsError = null;
    harness.api.responses.add(backups([backupRecord()]));
    await tester.tap(find.byKey(BackupsView.retryKey));
    await tester.pumpAndSettle();

    expect(find.text('nvngx_dlss.dll'), findsOneWidget);
  });

  testWidgets('a deadline-exceeded load is treated as daemon unavailable', (
    tester,
  ) async {
    final harness = BackupsHarness();
    harness.api.listBackupsError = GrpcError.deadlineExceeded('slow');
    await pumpBackups(tester, harness);

    expect(find.text('Daemon unavailable'), findsOneWidget);
    expect(find.text(BackupFailureCopy.daemonUnavailable), findsOneWidget);
  });

  final reasonCases = <String, String>{
    'BACKUP_MISSING': BackupFailureCopy.backupMissing,
    'BACKUP_CORRUPT': BackupFailureCopy.backupCorrupt,
    'TARGET_FOLDER_MISSING': BackupFailureCopy.targetFolderMissing,
    'PERMISSION_DENIED': BackupFailureCopy.permissionDenied,
    'METADATA_STALE': BackupFailureCopy.metadataStale,
  };

  for (final entry in reasonCases.entries) {
    testWidgets('restore failure ${entry.key} shows its own copy', (
      tester,
    ) async {
      final harness = BackupsHarness([
        backups([backupRecord()]),
        backups([backupRecord()]),
      ]);
      await pumpBackups(tester, harness);
      harness.api.restoreBackupError = grpcErrorForReason(
        entry.key,
        message: 'untrusted status text',
      );

      await tester.tap(find.byKey(BackupsView.restoreButtonKey('backup-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BackupsView.confirmRestoreKey));
      await tester.pumpAndSettle();

      expect(find.byKey(BackupsView.operationErrorKey), findsOneWidget);
      expect(find.text('Restore failed'), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('untrusted status text'), findsNothing);
    });
  }

  testWidgets('delete failure daemon unavailable shows its copy', (
    tester,
  ) async {
    final harness = BackupsHarness([
      backups([backupRecord()]),
      backups([backupRecord()]),
    ]);
    await pumpBackups(tester, harness);
    harness.api.deleteBackupError = const GrpcError.unavailable('socket gone');

    await tester.tap(find.byKey(BackupsView.deleteButtonKey('backup-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupsView.confirmDeleteKey));
    await tester.pumpAndSettle();

    expect(find.text('Delete failed'), findsOneWidget);
    expect(find.text(BackupFailureCopy.daemonUnavailable), findsOneWidget);
  });
}
