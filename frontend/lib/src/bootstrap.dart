import 'dart:io';

import 'package:grpc/grpc.dart';

import 'app_environment.dart';
import 'app_exit.dart';
import 'data/app_paths.dart';
import 'data/daemon_client.dart';
import 'data/daemon_connection.dart';
import 'data/directory_picker.dart';
import 'data/launcher_detection.dart';
import 'data/ui_settings.dart';
import 'ui/settings/settings_view_model.dart';

/// Starts the real application: resolves the explicit paths, loads `ui.json`,
/// and wires the daemon client, controller and settings view model.
Future<AppEnvironment> bootstrap() async {
  final paths = await AppPaths.resolve();
  final store = UiSettingsStore(File('${paths.dataDir}/ui.json'));
  final saved = await store.load();
  final dllSourceDir = saved.dllSourceDir ?? paths.defaultDllSourceDir;
  await Directory(dllSourceDir).create(recursive: true);

  final client = DaemonClient(
    config: DaemonClientConfig(
      dataDir: paths.dataDir,
      socketPath: paths.socketPath,
      dllSourceDir: dllSourceDir,
      executable: paths.executable,
    ),
    processStarter: _startProcess,
    channelFactory: _unixChannel,
  );
  final connection = DaemonController(client: client);
  final settings = SettingsViewModel(
    store: store,
    picker: const NativeDirectoryPicker(),
    connection: connection,
    dataDir: paths.dataDir,
    detector: const FileSystemLauncherDetector(),
    initial: saved.copyWith(dllSourceDir: dllSourceDir),
  );
  return AppEnvironment(
    api: client.api,
    connection: connection,
    settings: settings,
    exitHandler: AppExitHandler(connection),
  );
}

Future<Process> _startProcess(String executable, List<String> arguments) {
  return Process.start(executable, arguments);
}

ClientChannel _unixChannel(String socketPath) {
  return ClientChannel(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );
}
