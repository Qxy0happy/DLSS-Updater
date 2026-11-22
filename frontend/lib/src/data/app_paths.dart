import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'daemon_client.dart';

/// Longest usable Unix socket path in bytes (sockaddr_un.sun_path minus NUL).
const int maxSocketPathLength = 107;

const String _dataDirOverride = String.fromEnvironment('DLSS_DATA_DIR');
const String _runtimeDirOverride = String.fromEnvironment('DLSS_RUNTIME_DIR');
const String _daemonBinary = String.fromEnvironment('DLSSD_BIN');

/// Everything the frontend needs to locate the data directory and socket.
///
/// Development runs override the data directory with `DLSS_DATA_DIR`; the
/// default is `<app support>/dlss-updater-dev`, never the old app's real
/// configuration directory.
class AppPaths {
  const AppPaths({
    required this.dataDir,
    required this.runtimeDir,
    required this.socketPath,
    required this.defaultDllSourceDir,
    required this.executable,
  });

  final String dataDir;
  final String runtimeDir;
  final String socketPath;
  final String defaultDllSourceDir;
  final String executable;

  static Future<AppPaths> resolve({
    Map<String, String>? environment,
    int? processId,
    Future<Directory> Function()? supportDirectory,
  }) async {
    final env = environment ?? Platform.environment;
    String dataDir;
    if (_dataDirOverride.isNotEmpty) {
      dataDir = _dataDirOverride;
    } else {
      final support =
          await (supportDirectory ?? getApplicationSupportDirectory)();
      dataDir = '${support.path}/dlss-updater-dev';
    }

    if (!dataDir.startsWith('/')) {
      throw DaemonConfigException(
        'The data directory must be an absolute path: $dataDir',
      );
    }
    final runtimeDir = _runtimeDirOverride.isNotEmpty
        ? _runtimeDirOverride
        : (env['XDG_RUNTIME_DIR'] ?? Directory.systemTemp.path);
    if (!runtimeDir.startsWith('/')) {
      throw DaemonConfigException(
        'The runtime directory must be an absolute path: $runtimeDir',
      );
    }
    final socketPath = buildSocketPath(runtimeDir, processId ?? pid);
    final executable = _daemonBinary.isNotEmpty ? _daemonBinary : 'dlssd';
    final defaultDllSourceDir = '$dataDir/dll-source';

    await Directory(dataDir).create(recursive: true);
    return AppPaths(
      dataDir: dataDir,
      runtimeDir: runtimeDir,
      socketPath: socketPath,
      defaultDllSourceDir: defaultDllSourceDir,
      executable: executable,
    );
  }
}

/// Builds `$XDG_RUNTIME_DIR/dlss-updater/daemon-<pid>.sock` and rejects a path
/// that would not fit in `sun_path`.
String buildSocketPath(String runtimeDir, int processId) {
  final path = '$runtimeDir/dlss-updater/daemon-$processId.sock';
  if (path.length > maxSocketPathLength) {
    throw DaemonConfigException(
      'The runtime socket path is ${path.length} bytes but the Linux limit is '
      '$maxSocketPathLength: $path',
    );
  }
  return path;
}
