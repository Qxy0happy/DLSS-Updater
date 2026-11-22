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

  test('round-trips the Steam root, DLL source and custom folders', () async {
    await store.save(
      const UiSettings(
        steamRoot: '/steam/library',
        dllSourceDir: '/dll/source',
        customFolders: ['/games/ZZZ', '/games/Other'],
      ),
    );

    final raw =
        jsonDecode(store.file.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['steam_root'], '/steam/library');
    expect(raw['dll_source_dir'], '/dll/source');
    expect(raw['custom_folders'], ['/games/ZZZ', '/games/Other']);

    final loaded = await store.load();
    expect(loaded.steamRoot, '/steam/library');
    expect(loaded.dllSourceDir, '/dll/source');
    expect(loaded.customFolders, ['/games/ZZZ', '/games/Other']);
  });

  test('round-trips explicit launcher toggles', () async {
    await store.save(
      const UiSettings(heroicEnabled: false, lutrisEnabled: true),
    );

    final loaded = await store.load();
    expect(loaded.heroicEnabled, isFalse);
    expect(loaded.lutrisEnabled, isTrue);
  });

  test('clearing the Steam root keeps custom folders', () async {
    const initial = UiSettings(
      steamRoot: '/steam/library',
      customFolders: ['/games/ZZZ'],
    );
    await store.save(initial);

    await store.save(initial.copyWith(clearSteamRoot: true));

    final loaded = await store.load();
    expect(loaded.steamRoot, isNull);
    expect(loaded.customFolders, ['/games/ZZZ']);
  });

  test('malformed custom folders are dropped', () async {
    store.file.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'custom_folders': ['/games/ZZZ', '  ', 42, '/games/ZZZ', ''],
      }),
    );

    final loaded = await store.load();

    expect(loaded.customFolders, ['/games/ZZZ']);
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
