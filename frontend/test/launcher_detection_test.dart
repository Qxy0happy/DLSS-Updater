import 'dart:io';

import 'package:dlss_updater/src/data/launcher_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('dlss-launcher-detect-');
  });

  tearDown(() {
    home.deleteSync(recursive: true);
  });

  test('detects native Heroic and Lutris paths', () async {
    final heroic = Directory('${home.path}/.config/heroic')
      ..createSync(recursive: true);
    final lutris = File('${home.path}/.local/share/lutris/pga.db')
      ..createSync(recursive: true);

    final detection = await FileSystemLauncherDetector(home: home.path)
        .detect();

    expect(detection.heroicConfig, heroic.path);
    expect(detection.lutrisDatabase, lutris.path);
  });

  test('prefers the XDG locations and finds Flatpak Heroic', () async {
    final xdgHeroic = Directory('${home.path}/xdg-config/heroic')
      ..createSync(recursive: true);
    final xdgLutris = File('${home.path}/xdg-data/lutris/pga.db')
      ..createSync(recursive: true);

    final detection = await FileSystemLauncherDetector(
      home: '${home.path}/missing-home',
      xdgConfigHome: '${home.path}/xdg-config',
      xdgDataHome: '${home.path}/xdg-data',
    ).detect();

    expect(detection.heroicConfig, xdgHeroic.path);
    expect(detection.lutrisDatabase, xdgLutris.path);

    Directory('${home.path}/.var/app/com.heroicgameslauncher.hgl/config/heroic')
        .createSync(recursive: true);
    File('${home.path}/.var/app/net.lutris.Lutris/data/lutris/pga.db')
        .createSync(recursive: true);
    final flatpak = await FileSystemLauncherDetector(
      home: home.path,
      xdgConfigHome: '${home.path}/nothing-here',
      xdgDataHome: '${home.path}/nothing-here',
    ).detect();
    expect(
      flatpak.heroicConfig,
      '${home.path}/.var/app/com.heroicgameslauncher.hgl/config/heroic',
    );
    expect(
      flatpak.lutrisDatabase,
      '${home.path}/.var/app/net.lutris.Lutris/data/lutris/pga.db',
    );
  });

  test('missing launchers report absent', () async {
    final detection = await FileSystemLauncherDetector(
      home: home.path,
      xdgConfigHome: '${home.path}/missing-xdg-config',
      xdgDataHome: '${home.path}/missing-xdg-data',
    ).detect();

    expect(detection.heroic, isFalse);
    expect(detection.lutris, isFalse);
  });
}
