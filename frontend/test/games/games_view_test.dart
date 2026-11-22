import 'dart:async';

import 'package:dlss_updater/src/data/daemon_api.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/data/ui_settings.dart';
import 'package:dlss_updater/src/theme.dart';
import 'package:dlss_updater/src/ui/games/games_view.dart';
import 'package:dlss_updater/src/ui/settings/settings_view_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';

import '../support/fake_app_environment.dart';
import '../support/fake_daemon_api.dart';

class FakeSettingsStore implements SettingsStore {
  UiSettings saved = const UiSettings();

  @override
  Future<UiSettings> load() async => saved;

  @override
  Future<void> save(UiSettings settings) async {
    saved = settings;
  }
}

class GamesHarness {
  GamesHarness({UiSettings initial = const UiSettings(steamRoot: '/steam')}) {
    api = FakeDaemonApi();
    store = FakeSettingsStore();
    picker = FakeDirectoryPicker();
    connection = FakeDaemonConnection();
    settings = SettingsViewModel(
      store: store,
      picker: picker,
      connection: connection,
      dataDir: '/tmp/dlss-data',
      initial: initial,
    );
  }

  late final FakeDaemonApi api;
  late final FakeSettingsStore store;
  late final FakeDirectoryPicker picker;
  late final FakeDaemonConnection connection;
  late final SettingsViewModel settings;

  Widget build() {
    return MultiProvider(
      providers: [
        Provider<DaemonApi>.value(value: api),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
        ChangeNotifierProvider<DaemonConnection>.value(value: connection),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: GamesView()),
      ),
    );
  }

  void dispose() {
    settings.dispose();
    connection.dispose();
  }
}

Game gameWith({
  String id = 'game-1',
  String name = 'Fixture Game',
  List<GameDLL> dlls = const [],
}) {
  return Game(
    id: id,
    appId: 42,
    name: name,
    installPath: '/steam/steamapps/common/Fixture',
    libraryPath: '/steam',
    dlls: dlls,
  );
}

ScanEvent started() => ScanEvent(started: ScanStarted(steamRoot: '/steam'));

ScanEvent progress({
  int sourceIndex = 1,
  int sourceCount = 2,
  String currentGame = 'Fixture Game',
  int gamesFound = 1,
  int dllsFound = 3,
}) {
  return ScanEvent(
    libraryProgress: ScanLibraryProgress(
      libraryPath: '/steam',
      libraryIndex: sourceIndex,
      libraryCount: sourceCount,
      currentGame: currentGame,
      gamesFound: gamesFound,
      dllsFound: dllsFound,
    ),
  );
}

ScanEvent finished({int games = 1, int dlls = 3, bool cancelled = false}) {
  return ScanEvent(
    finished: ScanFinished(
      gameCount: games,
      dllCount: dlls,
      cancelled: cancelled,
      durationMs: Int64(1200),
    ),
  );
}

class _ErrorCase {
  const _ErrorCase(
    this.reason,
    this.snippet,
    this.retryLabel, {
    this.code = StatusCode.failedPrecondition,
  });

  final String reason;
  final String snippet;
  final String retryLabel;
  final int code;
}

void main() {
  testWidgets('shows the empty state before any scan', (tester) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(find.text(GamesView.emptyTitle), findsOneWidget);
    expect(find.text(GamesView.emptyMessage), findsOneWidget);
    expect(find.byKey(GamesView.chooseRootKey), findsOneWidget);
    expect(find.byKey(GamesView.scanKey), findsOneWidget);
    expect(find.text('/steam'), findsOneWidget);
    expect(harness.api.listGamesRequests, hasLength(1));
  });

  testWidgets('scan streams progress, found games and a finish summary', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    final controller = StreamController<ScanEvent>();
    harness.api.scanController = controller;

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pump();

    expect(harness.api.startScanRequests, hasLength(1));
    final request = harness.api.startScanRequests.single;
    expect(request.sources, hasLength(1));
    expect(request.sources.single.steam.root, '/steam');

    controller.add(started());
    controller.add(progress());
    await tester.pump();

    expect(find.byKey(GamesView.progressKey), findsOneWidget);
    expect(find.text('Source 1 of 2'), findsOneWidget);
    expect(find.text('Checking Fixture Game'), findsOneWidget);
    expect(find.text('1 game · 3 DLLs found'), findsOneWidget);
    expect(find.byKey(GamesView.cancelKey), findsOneWidget);

    controller.add(ScanEvent(gameFound: gameWith()));
    harness.api.listGamesResponse = ListGamesResponse(games: [gameWith()]);
    await tester.pump();
    expect(find.text('Fixture Game'), findsOneWidget);

    controller.add(finished());
    await tester.pumpAndSettle();

    expect(find.byKey(GamesView.progressKey), findsNothing);
    expect(find.text('Scan complete'), findsOneWidget);
    expect(find.text('1 game · 3 DLLs · 1.2 s'), findsOneWidget);
    expect(find.text('Fixture Game'), findsOneWidget);
  });

  testWidgets('cancelling mid-scan keeps the partial list and summary', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    final controller = StreamController<ScanEvent>();
    harness.api.scanController = controller;

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pump();

    controller.add(started());
    controller.add(progress());
    controller.add(ScanEvent(gameFound: gameWith()));
    await tester.pump();
    expect(find.text('Fixture Game'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.cancelKey));
    await tester.pumpAndSettle();

    expect(harness.api.scanCancelled, isTrue);
    expect(find.byKey(GamesView.progressKey), findsNothing);
    expect(find.text('Scan cancelled'), findsOneWidget);
    expect(find.textContaining('1 game · 3 DLLs kept'), findsOneWidget);
    expect(find.text('Fixture Game'), findsOneWidget);
    expect(find.byKey(GamesView.errorKey), findsNothing);
    expect(harness.api.listGamesRequests.length, greaterThan(1));
  });

  const errorCases = [
    _ErrorCase(
      'SCAN_ROOT_INVALID',
      'One or more scan folders cannot be read',
      'Choose folder',
    ),
    _ErrorCase('SCAN_IN_PROGRESS', 'A scan is already running', 'Scan again'),
    _ErrorCase(
      'PERMISSION_DENIED',
      'Part of the selected folder could not be read',
      'Scan again',
    ),
    _ErrorCase(
      'CANCELLED',
      'The scan was cancelled before it finished',
      'Scan again',
    ),
    _ErrorCase(
      'METADATA_STALE',
      'The stored game data is out of date',
      'Scan again',
    ),
    _ErrorCase('INTERNAL', 'The daemon hit an internal error', 'Scan again'),
    _ErrorCase(
      'INTERNAL',
      'The daemon is not reachable',
      'Retry',
      code: StatusCode.unavailable,
    ),
    // UNKNOWN and DEADLINE_EXCEEDED mean the same thing to the UI: retry the
    // connection instead of blaming the request.
    _ErrorCase(
      'INTERNAL',
      'The daemon is not reachable',
      'Retry',
      code: StatusCode.unknown,
    ),
    _ErrorCase(
      'INTERNAL',
      'The daemon is not reachable',
      'Retry',
      code: StatusCode.deadlineExceeded,
    ),
  ];

  for (final errorCase in errorCases) {
    testWidgets('shows the ${errorCase.reason} message with its retry action '
        '(code ${errorCase.code})', (tester) async {
      final harness = GamesHarness();
      addTearDown(harness.dispose);
      harness.api.startScanError = grpcErrorForReason(
        errorCase.reason,
        message: 'server detail',
        code: errorCase.code,
      );

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GamesView.scanKey));
      await tester.pumpAndSettle();

      expect(find.byKey(GamesView.errorKey), findsOneWidget);
      expect(find.textContaining(errorCase.snippet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(GamesView.errorKey),
          matching: find.text(errorCase.retryLabel),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a scan stream without finished ends in an error state', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.scanEvents = [started()];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();

    expect(find.byKey(GamesView.errorKey), findsOneWidget);
    expect(find.textContaining('ended unexpectedly'), findsOneWidget);
    expect(find.text('Scan complete'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(GamesView.errorKey),
        matching: find.text('Scan again'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a scan with no results shows the no-results empty state', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 0)];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();

    expect(find.text(GamesView.noResultsTitle), findsOneWidget);
    expect(find.text(GamesView.noResultsMessage), findsOneWidget);
  });

  testWidgets('choosing a Steam root persists it and is used by the scan', (
    tester,
  ) async {
    final harness = GamesHarness(initial: const UiSettings());
    addTearDown(harness.dispose);
    harness.picker.queuedPaths.add('/home/user/Steam');
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 0)];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text('No sources selected'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.chooseRootKey));
    await tester.pumpAndSettle();

    expect(harness.store.saved.steamRoot, '/home/user/Steam');
    expect(find.text('/home/user/Steam'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    expect(
      harness.api.startScanRequests.single.sources.single.steam.root,
      '/home/user/Steam',
    );
  });

  testWidgets('SCAN_ROOT_INVALID retry opens the folder picker', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.startScanError = grpcErrorForReason(
      'SCAN_ROOT_INVALID',
      message: '/steam is not a directory',
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GamesView.errorKey), findsOneWidget);

    harness.picker.queuedPaths.add('/fixed/steam');
    await tester.tap(find.byKey(GamesView.retryKey));
    await tester.pumpAndSettle();

    expect(harness.picker.calls, 1);
    expect(harness.store.saved.steamRoot, '/fixed/steam');
    expect(find.byKey(GamesView.errorKey), findsNothing);
  });

  testWidgets('daemon unavailable retry asks the connection to reconnect', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.startScanError = grpcErrorForReason(
      'INTERNAL',
      message: 'daemon is down',
      code: StatusCode.unavailable,
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('The daemon is not reachable'), findsOneWidget);

    harness.api.startScanError = null;
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 0)];
    await tester.tap(find.byKey(GamesView.retryKey));
    await tester.pumpAndSettle();

    expect(harness.connection.retryCalls, 1);
    expect(harness.api.startScanRequests, hasLength(2));
  });

  testWidgets('game detail shows DLL rows, missing target and source version', (
    tester,
  ) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.listGamesResponse = ListGamesResponse(
      games: [
        gameWith(
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
            GameDLL(
              id: 'dll-2',
              gameId: 'game-1',
              dllType: 'dlss_g',
              filename: 'nvngx_dlssg.dll',
              path: '/steam/steamapps/common/Fixture/nvngx_dlssg.dll',
              currentVersion: '0.0.0',
              sourceVersion: '',
              exists: false,
              missingAt: Timestamp.fromDateTime(DateTime.utc(2026, 11, 20, 12)),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text('1 DLL'), findsNothing);
    expect(find.text('2 DLLs'), findsOneWidget);

    await tester.tap(find.byKey(const Key('game-game-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game-detail')), findsOneWidget);
    expect(find.text('DLSS'), findsOneWidget);
    expect(find.text('DLSS Frame Generation'), findsOneWidget);
    expect(find.text('nvngx_dlss.dll'), findsOneWidget);
    expect(
      find.text('/steam/steamapps/common/Fixture/nvngx_dlss.dll'),
      findsOneWidget,
    );
    expect(find.text('Current 2.4.2.0'), findsOneWidget);
    expect(find.text('Source 3.7.10.0'), findsOneWidget);
    expect(find.text('On disk'), findsOneWidget);
    expect(find.text('Not on disk'), findsOneWidget);
    expect(find.text('No source file'), findsOneWidget);
    expect(find.textContaining('Missing since 2026-11-20'), findsOneWidget);

    final checkbox = find.byKey(const Key('dll-select-dll-1'));
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('adds a custom folder and scans it without Steam', (
    tester,
  ) async {
    final harness = GamesHarness(initial: const UiSettings());
    addTearDown(harness.dispose);
    harness.picker.queuedPaths.add('/games/ZZZ');
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 16)];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text('No sources selected'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(GamesView.scanKey)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(GamesView.addCustomFolderKey));
    await tester.pumpAndSettle();
    expect(harness.store.saved.customFolders, ['/games/ZZZ']);
    expect(find.text('/games/ZZZ'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    final request = harness.api.startScanRequests.single;
    expect(request.sources, hasLength(1));
    expect(request.sources.single.customFolder.path, '/games/ZZZ');
  });

  testWidgets('removes a custom folder from the scan sources', (tester) async {
    final harness = GamesHarness(
      initial: const UiSettings(customFolders: ['/games/ZZZ', '/games/Other']),
    );
    addTearDown(harness.dispose);
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 0)];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text('/games/ZZZ'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.removeCustomFolderKey('/games/ZZZ')));
    await tester.pumpAndSettle();
    expect(harness.store.saved.customFolders, ['/games/Other']);
    expect(find.text('/games/ZZZ'), findsNothing);

    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    final sources = harness.api.startScanRequests.single.sources;
    expect(sources, hasLength(1));
    expect(sources.single.customFolder.path, '/games/Other');
  });

  testWidgets('warnings stay visible after the scan finishes', (tester) async {
    final harness = GamesHarness();
    addTearDown(harness.dispose);
    harness.api.scanEvents = [
      started(),
      progress(),
      ScanEvent(
        warning: ScanWarning(
          path: '/gone',
          message:
              'This custom folder is missing or unreadable; it is skipped.',
        ),
      ),
      finished(games: 0, dlls: 0),
    ];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();

    expect(find.byKey(GamesView.warningsKey), findsOneWidget);
    expect(find.text('1 scan warning'), findsOneWidget);
    expect(find.text('/gone'), findsNothing);

    await tester.tap(find.text('1 scan warning'));
    await tester.pumpAndSettle();
    expect(find.text('/gone'), findsOneWidget);
    expect(
      find.text('This custom folder is missing or unreadable; it is skipped.'),
      findsOneWidget,
    );
  });

  testWidgets('clearing Steam keeps custom folders scannable', (tester) async {
    final harness = GamesHarness(
      initial: const UiSettings(
        steamRoot: '/steam',
        customFolders: ['/games/ZZZ'],
      ),
    );
    addTearDown(harness.dispose);
    harness.api.scanEvents = [started(), finished(games: 0, dlls: 0)];

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.clearRootKey));
    await tester.pumpAndSettle();

    expect(harness.store.saved.steamRoot, isNull);
    expect(find.text('1 custom folder'), findsOneWidget);

    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    final sources = harness.api.startScanRequests.single.sources;
    expect(sources, hasLength(1));
    expect(sources.single.customFolder.path, '/games/ZZZ');
  });

  testWidgets('SCAN_ROOT_INVALID retry picks a custom folder when only custom '
      'sources exist', (tester) async {
    final harness = GamesHarness(
      initial: const UiSettings(customFolders: ['/games/ZZZ']),
    );
    addTearDown(harness.dispose);
    harness.api.startScanError = grpcErrorForReason(
      'SCAN_ROOT_INVALID',
      message: '/games/ZZZ is not readable',
    );

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GamesView.scanKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GamesView.errorKey), findsOneWidget);

    harness.picker.queuedPaths.add('/games/Other');
    await tester.tap(find.byKey(GamesView.retryKey));
    await tester.pumpAndSettle();

    expect(harness.picker.calls, 1);
    expect(harness.store.saved.customFolders, ['/games/ZZZ', '/games/Other']);
    expect(find.byKey(GamesView.errorKey), findsNothing);
  });
}
