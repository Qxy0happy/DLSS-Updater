import 'data/daemon_api.dart';
import 'data/daemon_connection.dart';
import 'ui/settings/settings_view_model.dart';
import 'app_exit.dart';

/// The root provider payload. Tests build it with fakes; `bootstrap()` builds
/// the real one.
class AppEnvironment {
  const AppEnvironment({
    required this.api,
    required this.connection,
    required this.settings,
    required this.exitHandler,
  });

  /// The protocol seam later feature repositories read from the root.
  final DaemonApi api;
  final DaemonConnection connection;
  final SettingsViewModel settings;
  final AppExitHandler exitHandler;
}
