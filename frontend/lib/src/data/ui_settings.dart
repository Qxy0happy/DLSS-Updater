import 'dart:convert';
import 'dart:io';

/// The frontend-owned settings file in the data directory.
///
/// The sidecar owns `db.sqlite3` and `logs/`; this file belongs to the app so
/// the two never write each other's data.
class UiSettings {
  const UiSettings({this.steamRoot, this.dllSourceDir});

  /// The Steam root chosen in the Games view. It is preserved across saves so
  /// a temporary load failure never loses the user's choice.
  final String? steamRoot;

  /// The DLL source directory passed to dlssd as `--dll-source-dir`.
  final String? dllSourceDir;

  UiSettings copyWith({String? steamRoot, String? dllSourceDir}) {
    return UiSettings(
      steamRoot: steamRoot ?? this.steamRoot,
      dllSourceDir: dllSourceDir ?? this.dllSourceDir,
    );
  }
}

/// Persistence seam for [UiSettings]; widget tests use an in-memory fake.
abstract class SettingsStore {
  Future<UiSettings> load();

  Future<void> save(UiSettings settings);
}

/// Reads and writes `<data-dir>/ui.json`.
///
/// A missing or corrupt file is treated as empty settings: the app must always
/// be able to start and let the user choose directories again.
class UiSettingsStore implements SettingsStore {
  UiSettingsStore(this.file);

  final File file;

  @override
  Future<UiSettings> load() async {
    String contents;
    try {
      contents = await file.readAsString();
    } on FileSystemException {
      return const UiSettings();
    }
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        return const UiSettings();
      }
      return UiSettings(
        steamRoot: _asPath(decoded['steam_root']),
        dllSourceDir: _asPath(decoded['dll_source_dir']),
      );
    } on FormatException {
      return const UiSettings();
    }
  }

  @override
  Future<void> save(UiSettings settings) async {
    await file.parent.create(recursive: true);
    final payload = jsonEncode(<String, Object?>{
      'steam_root': settings.steamRoot,
      'dll_source_dir': settings.dllSourceDir,
    });
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(payload, flush: true);
    await temporary.rename(file.path);
  }

  static String? _asPath(Object? value) {
    if (value is! String) return null;
    return value.trim().isEmpty ? null : value;
  }
}
