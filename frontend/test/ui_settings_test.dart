import 'dart:convert';
import 'dart:io';

import 'package:dlss_updater/src/data/ui_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late UiSettingsStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('dlss-ui-settings-');
    store = UiSettingsStore(File('${directory.path}/ui.json'));
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('missing file loads empty settings', () async {
    final settings = await store.load();
    expect(settings.steamRoot, isNull);
    expect(settings.dllSourceDir, isNull);
  });

  test('round-trips the Steam root and DLL source', () async {
    await store.save(
      const UiSettings(
        steamRoot: '/steam/library',
        dllSourceDir: '/dll/source',
      ),
    );

    final raw =
        jsonDecode(store.file.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['steam_root'], '/steam/library');
    expect(raw['dll_source_dir'], '/dll/source');

    final loaded = await store.load();
    expect(loaded.steamRoot, '/steam/library');
    expect(loaded.dllSourceDir, '/dll/source');
  });

  test('changing the DLL source preserves the Steam root', () async {
    await store.save(const UiSettings(steamRoot: '/steam/library'));
    final loaded = await store.load();

    await store.save(loaded.copyWith(dllSourceDir: '/other/source'));

    final saved = await store.load();
    expect(saved.steamRoot, '/steam/library');
    expect(saved.dllSourceDir, '/other/source');
  });

  test('corrupt JSON loads empty settings', () async {
    store.file.writeAsStringSync('{not json');

    final loaded = await store.load();

    expect(loaded.steamRoot, isNull);
    expect(loaded.dllSourceDir, isNull);
  });

  test('empty strings are treated as absent', () async {
    store.file.writeAsStringSync(
      jsonEncode(<String, String>{'steam_root': '   ', 'dll_source_dir': ''}),
    );

    final loaded = await store.load();

    expect(loaded.steamRoot, isNull);
    expect(loaded.dllSourceDir, isNull);
  });
}
