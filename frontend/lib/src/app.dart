import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_environment.dart';
import 'data/daemon_api.dart';
import 'data/daemon_connection.dart';
import 'theme.dart';
import 'ui/app_shell.dart';
import 'ui/settings/settings_view_model.dart';

/// Root widget: one provider tree, Material 3 with a seeded scheme following
/// the system theme.
///
/// It also owns the desktop exit hook: the sidecar is shut down before the
/// process exits, so no orphan or leftover socket remains.
class DlssUpdaterApp extends StatefulWidget {
  const DlssUpdaterApp({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<DlssUpdaterApp> createState() => _DlssUpdaterAppState();
}

class _DlssUpdaterAppState extends State<DlssUpdaterApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: widget.environment.exitHandler.onExitRequested,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DaemonApi>.value(value: widget.environment.api),
        ChangeNotifierProvider<DaemonConnection>.value(
          value: widget.environment.connection,
        ),
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: widget.environment.settings,
        ),
      ],
      child: MaterialApp(
        title: 'DLSS Updater',
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}

/// Shown when the app cannot resolve its paths at all; no daemon is started,
/// so the message must explain what to fix.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(title: const Text('DLSS Updater')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text('The application could not start.'),
                const SizedBox(height: 8),
                SelectableText(error.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
