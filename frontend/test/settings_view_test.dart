import 'dart:io';

import 'package:dlss_updater/src/data/daemon_client.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/data/daemon_api.dart' show Status;
import 'package:dlss_updater/src/data/ui_settings.dart';
import 'package:dlss_updater/src/ui/settings/settings_view.dart';
import 'package:dlss_updater/src/ui/settings/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fake_app_environment.dart';
import 'support/fake_daemon_api.dart';
import 'support/fake_daemon_process.dart';

class FakeSettingsStore implements SettingsStore {
  UiSettings saved = const UiSettings();
  Object? saveError;

  @override
  Future<UiSettings> load() async => saved;

  @override
  Future<void> save(UiSettings settings) async {
    final error = saveError;
    if (error != null) throw error;
    saved = settings;
  }
}

class SettingsHarness {
  SettingsHarness({UiSettings initial = const UiSettings()}) {
    directory = Directory.systemTemp.createTempSync('dlss-settings-test-');
    picker = FakeDirectoryPicker();
    store = FakeSettingsStore();
    api = FakeDaemonApi()
      ..status = Status(protoVersion: 'dlss.v1', appVersion: '1.2.3');
    processes = FakeProcessStarter();
    client = DaemonClient(
      config: DaemonClientConfig(
        dataDir: directory.path,
        socketPath: '${directory.path}/daemon.sock',
        dllSourceDir: initial.dllSourceDir ?? '/old/source',
        executable: '/usr/bin/dlssd',
      ),
      processStarter: processes.start,
      api: api,
      exitGrace: const Duration(milliseconds: 5),
      handshakeTimeout: const Duration(milliseconds: 50),
      handshakePoll: const Duration(milliseconds: 1),
    );
    connection = DaemonController(
      client: client,
      backoff: (_) => Duration.zero,
    );
    viewModel = SettingsViewModel(
      store: store,
      picker: picker,
      connection: connection,
      dataDir: directory.path,
      initial: initial.copyWith(
        dllSourceDir: initial.dllSourceDir ?? '/old/source',
      ),
    );
  }

  late final Directory directory;
  late final FakeDaemonApi api;
  late final FakeProcessStarter processes;
  late final DaemonClient client;
  late final DaemonController connection;
  late final FakeDirectoryPicker picker;
  late final FakeSettingsStore store;
  late final SettingsViewModel viewModel;

  Future<void> start() => connection.start();

  Widget build() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DaemonConnection>.value(value: connection),
        ChangeNotifierProvider<SettingsViewModel>.value(value: viewModel),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsView())),
    );
  }

  void dispose() {
    viewModel.dispose();
    connection.dispose();
    directory.deleteSync(recursive: true);
  }
}

void main() {
  testWidgets('shows directories and versions', (tester) async {
    final harness = SettingsHarness();
    addTearDown(harness.dispose);
    await harness.start();
    await tester.pumpWidget(harness.build());

    expect(find.text(harness.directory.path), findsOneWidget);
    expect(find.text('/old/source'), findsOneWidget);
    expect(find.text('App version'), findsOneWidget);
    expect(find.text(harness.connection.daemonVersion!), findsOneWidget);
    expect(find.text(harness.connection.protoVersion!), findsOneWidget);
  });

  testWidgets('changing the source persists settings and restarts', (
    tester,
  ) async {
    final harness = SettingsHarness(
      initial: const UiSettings(steamRoot: '/steam/library'),
    );
    addTearDown(harness.dispose);
    await harness.start();
    final chosen = Directory.systemTemp.createTempSync('dlss-new-source-');
    addTearDown(() => chosen.deleteSync(recursive: true));
    harness.picker.queuedPaths.add(chosen.path);

    await tester.pumpWidget(harness.build());
    await tester.tap(find.byKey(const Key(SettingsView.changeSourceKey)));
    await tester.pumpAndSettle();

    expect(harness.viewModel.changingSource, isFalse);

    expect(
      harness.processes.calls.last,
      containsAllInOrder(<String>['--dll-source-dir', chosen.path]),
    );
    expect(find.text(chosen.path), findsOneWidget);
    expect(harness.store.saved.dllSourceDir, chosen.path);
    expect(harness.store.saved.steamRoot, '/steam/library');
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final harness = SettingsHarness();
    addTearDown(harness.dispose);
    await harness.start();

    await tester.pumpWidget(harness.build());
    await tester.tap(find.byKey(const Key(SettingsView.changeSourceKey)));
    await tester.pumpAndSettle();

    expect(harness.picker.calls, 1);
    expect(harness.processes.calls, hasLength(1));
    expect(find.text('/old/source'), findsOneWidget);
  });

  testWidgets('a store failure is shown without restarting', (tester) async {
    final harness = SettingsHarness();
    addTearDown(harness.dispose);
    await harness.start();
    harness.store.saveError = const FileSystemException('read-only');
    harness.picker.queuedPaths.add('/new/source');

    await tester.pumpWidget(harness.build());
    await tester.tap(find.byKey(const Key(SettingsView.changeSourceKey)));
    await tester.pumpAndSettle();

    expect(find.text('Could not change the DLL source'), findsOneWidget);
    expect(harness.processes.calls, hasLength(1));
    expect(find.text('/old/source'), findsOneWidget);
  });
}
