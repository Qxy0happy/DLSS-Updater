import 'dart:io';

import 'package:dlss_updater/src/data/app_paths.dart';
import 'package:dlss_updater/src/data/daemon_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildSocketPath follows the daemon-<pid> convention', () {
    expect(
      buildSocketPath('/run/user/1000', 42),
      '/run/user/1000/dlss-updater/daemon-42.sock',
    );
  });

  test('buildSocketPath rejects a path over the sun_path limit', () {
    expect(
      () => buildSocketPath('/run/${'x' * maxSocketPathLength}', 1),
      throwsA(isA<DaemonConfigException>()),
    );
  });

  test('resolve uses the app support directory and XDG runtime dir', () async {
    final support = Directory.systemTemp.createTempSync('dlss-support-');
    final runtime = Directory.systemTemp.createTempSync('dlss-runtime-');
    addTearDown(() {
      support.deleteSync(recursive: true);
      runtime.deleteSync(recursive: true);
    });

    final paths = await AppPaths.resolve(
      environment: <String, String>{'XDG_RUNTIME_DIR': runtime.path},
      processId: 4242,
      supportDirectory: () async => support,
    );

    expect(paths.dataDir, '${support.path}/dlss-updater-dev');
    expect(paths.runtimeDir, runtime.path);
    expect(paths.socketPath, '${runtime.path}/dlss-updater/daemon-4242.sock');
    expect(paths.defaultDllSourceDir, '${paths.dataDir}/dll-source');
    expect(Directory(paths.dataDir).existsSync(), isTrue);
  });

  test('resolve rejects a relative runtime directory', () async {
    final support = Directory.systemTemp.createTempSync('dlss-support-');
    addTearDown(() => support.deleteSync(recursive: true));

    await expectLater(
      AppPaths.resolve(
        environment: <String, String>{'XDG_RUNTIME_DIR': 'relative/runtime'},
        processId: 4242,
        supportDirectory: () async => support,
      ),
      throwsA(isA<DaemonConfigException>()),
    );
  });
}
