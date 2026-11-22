import 'package:flutter/foundation.dart';

import '../../data/daemon_connection.dart';
import '../../data/directory_picker.dart';
import '../../data/launcher_detection.dart';
import '../../data/ui_settings.dart';

/// Settings state: the frontend-owned directories and the current daemon
/// versions. Changing the DLL source persists `ui.json` and restarts the
/// sidecar, because the frontend owns the process.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required this.store,
    required this.picker,
    required this.connection,
    required this.dataDir,
    this.detector = const NoLauncherDetector(),
    UiSettings initial = const UiSettings(),
  }) : _settings = initial;

  final SettingsStore store;
  final DirectoryPicker picker;
  final DaemonConnection connection;
  final String dataDir;
  final LauncherDetector detector;

  UiSettings _settings;
  LauncherDetection _detection = const LauncherDetection();
  String? _error;
  bool _changingSource = false;

  String get dllSourceDir => _settings.dllSourceDir ?? connection.dllSourceDir;

  String? get steamRoot => _settings.steamRoot;

  List<String> get customFolders => List.unmodifiable(_settings.customFolders);

  bool get heroicDetected => _detection.heroic;

  bool get lutrisDetected => _detection.lutris;

  /// A launcher is scanned only when it is detected and the persisted choice
  /// (or the default) is on. Auto-detection is the only path supported in v1.
  bool get heroicEnabled =>
      _detection.heroic && (_settings.heroicEnabled ?? true);

  bool get lutrisEnabled =>
      _detection.lutris && (_settings.lutrisEnabled ?? true);

  String? get error => _error;

  bool get changingSource => _changingSource;

  UiSettings get settings => _settings;

  /// Persists the Steam root chosen in the Games destination.
  Future<void> setSteamRoot(String steamRoot) async {
    final updated = _settings.copyWith(steamRoot: steamRoot);
    await store.save(updated);
    _settings = updated;
    notifyListeners();
  }

  /// Removes the Steam root while keeping every custom folder.
  Future<void> clearSteamRoot() async {
    final updated = _settings.copyWith(clearSteamRoot: true);
    await store.save(updated);
    _settings = updated;
    notifyListeners();
  }

  /// Detects the launcher configuration roots once per load. A detection
  /// failure means "not found"; it must not block the Games view.
  Future<void> detectLaunchers() async {
    try {
      final detection = await detector.detect();
      _detection = detection;
    } catch (_) {
      _detection = const LauncherDetection();
    }
    notifyListeners();
  }

  /// Persists an explicit Heroic toggle choice.
  Future<void> setHeroicEnabled(bool enabled) async {
    final updated = _settings.copyWith(heroicEnabled: enabled);
    await store.save(updated);
    _settings = updated;
    notifyListeners();
  }

  /// Persists an explicit Lutris toggle choice.
  Future<void> setLutrisEnabled(bool enabled) async {
    final updated = _settings.copyWith(lutrisEnabled: enabled);
    await store.save(updated);
    _settings = updated;
    notifyListeners();
  }

  /// Persists the custom game folder list.
  Future<void> setCustomFolders(List<String> customFolders) async {
    final updated = _settings.copyWith(
      customFolders: List<String>.unmodifiable(customFolders),
    );
    await store.save(updated);
    _settings = updated;
    notifyListeners();
  }

  /// Opens the picker for one game directory and appends it.
  ///
  /// Returns the selected path, or null when the user closed the picker or
  /// chose a folder that is already in the list.
  Future<String?> chooseCustomFolder() async {
    final selected = await picker.pickDirectory();
    if (selected == null) return null;
    final path = selected.trim();
    if (path.isEmpty || _settings.customFolders.contains(path)) return null;
    await setCustomFolders([..._settings.customFolders, path]);
    return path;
  }

  /// Removes one custom game folder and persists the remaining list.
  Future<void> removeCustomFolder(String path) async {
    if (!_settings.customFolders.contains(path)) return;
    await setCustomFolders([
      for (final existing in _settings.customFolders)
        if (existing != path) existing,
    ]);
  }

  /// Opens the native picker for the Steam root and persists the choice.
  ///
  /// Returns the selected path, or null when the user closed the picker.
  Future<String?> chooseSteamRoot() async {
    final selected = await picker.pickDirectory(
      initialDirectory: _settings.steamRoot,
    );
    if (selected == null) return null;
    await setSteamRoot(selected);
    return selected;
  }

  /// Opens the native picker, persists the choice and restarts the daemon.
  Future<void> chooseDllSource() async {
    if (_changingSource) return;
    _changingSource = true;
    _error = null;
    notifyListeners();
    try {
      final selected = await picker.pickDirectory(
        initialDirectory: dllSourceDir,
      );
      if (selected == null) {
        return;
      }
      final updated = _settings.copyWith(dllSourceDir: selected);
      await store.save(updated);
      _settings = updated;
      notifyListeners();
      await connection.restartWithDllSource(selected);
      _error = connection.lastError;
    } catch (error) {
      _error = error.toString();
    } finally {
      _changingSource = false;
      notifyListeners();
    }
  }
}
