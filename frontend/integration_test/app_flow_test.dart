// Opt-in end-to-end test: launches the real application widget tree against a
// real dlssd process over a real Unix socket and scans a fixture Steam library.
//
// It is not run by `flutter test` (that only scans test/) and is additionally
// gated on DLSS_INTEGRATION=1. The make target `frontend-integration` documents
// the required environment; see docs/spec-15-runbook.md.
//
// Requires a graphical session: Flutter desktop integration tests open a
// window. Under xvfb it can run headless; see the runbook.
import 'dart:io';

import 'package:dlss_updater/src/app.dart';
import 'package:dlss_updater/src/app_environment.dart';
import 'package:dlss_updater/src/app_exit.dart';
import 'package:dlss_updater/src/data/daemon_client.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/data/directory_picker.dart';
import 'package:dlss_updater/src/data/ui_settings.dart';
import 'package:dlss_updater/src/ui/connection_banner.dart';
import 'package:dlss_updater/src/ui/games/games_view.dart';
import 'package:dlss_updater/src/ui/settings/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final enabled = Platform.environment['DLSS_INTEGRATION'] == '1';

  testWidgets(
    'connects to the real daemon and scans the fixture Steam library',
    skip: !enabled,
    (tester) async {
      final steamRoot = _requiredEnv('DLSS_FIXTURE_STEAM_ROOT');
      final binary = _requiredEnv('DLSSD_BIN');
      final gameName =
          Platform.environment['DLSS_FIXTURE_GAME'] ?? 'Fixture Game';
      final expectedVersion = Platform.environment['DLSS_EXPECTED_APP_VERSION'];

      final root = await Directory.systemTemp.createTemp('dlss-app-it-');
      final dataDir = '${root.path}/data';
      final dllSource = '${root.path}/dll-source';
      final socketPath = '${root.path}/daemon.sock';
      await Directory(dllSource).create(recursive: true);

      final store = UiSettingsStore(File('$dataDir/ui.json'));
      await store.save(
        UiSettings(steamRoot: steamRoot, dllSourceDir: dllSource),
      );

      final client = DaemonClient(
        config: DaemonClientConfig(
          dataDir: dataDir,
          socketPath: socketPath,
          dllSourceDir: dllSource,
          executable: binary,
        ),
        processStarter: (executable, arguments) =>
            Process.start(executable, arguments),
        channelFactory: (path) => ClientChannel(
          InternetAddress(path, type: InternetAddressType.unix),
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        ),
      );
      final connection = DaemonController(client: client);
      final settings = SettingsViewModel(
        store: store,
        picker: const _NoDirectoryPicker(),
        connection: connection,
        dataDir: dataDir,
        initial: UiSettings(steamRoot: steamRoot, dllSourceDir: dllSource),
      );

      addTearDown(() async {
        await connection.shutdown();
        if (root.existsSync()) {
          root.deleteSync(recursive: true);
        }
      });

      await connection.start();
      await tester.pumpWidget(
        DlssUpdaterApp(
          environment: AppEnvironment(
            api: client.api,
            connection: connection,
            settings: settings,
            exitHandler: AppExitHandler(connection),
          ),
        ),
      );
      await _pumpUntil(tester, find.text(ConnectionBanner.connectedLabel));

      // The fixture root comes from ui.json; the Scan button must be enabled
      // and drive the real StartScan stream.
      expect(find.byKey(GamesView.scanKey), findsOneWidget);
      await tester.tap(find.byKey(GamesView.scanKey));
      await _pumpUntil(
        tester,
        find.text(gameName),
        timeout: const Duration(minutes: 1),
      );

      // Settings shows the version injected at build time. When the make
      // target supplies DLSS_EXPECTED_APP_VERSION, it must match exactly.
      await tester.tap(find.text('Settings').last);
      await _pumpUntil(tester, find.text('App version'));
      if (expectedVersion != null && expectedVersion.isNotEmpty) {
        expect(find.text(expectedVersion), findsWidgets);
      }

      // Shutting down through the same controller removes the socket and the
      // sidecar process; the daemon must not outlive the app.
      await connection.shutdown();
      expect(File(socketPath).existsSync(), isFalse);
    },
  );
}

String _requiredEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    fail('$key is required when DLSS_INTEGRATION=1');
  }
  return value;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $finder');
}

class _NoDirectoryPicker implements DirectoryPicker {
  const _NoDirectoryPicker();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => null;
}
