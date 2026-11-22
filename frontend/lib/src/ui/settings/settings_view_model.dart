import 'package:flutter/foundation.dart';

import '../../data/daemon_connection.dart';
import '../../data/directory_picker.dart';
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
    UiSettings initial = const UiSettings(),
  }) : _settings = initial;

  final SettingsStore store;
  final DirectoryPicker picker;
  final DaemonConnection connection;
  final String dataDir;

  UiSettings _settings;
  String? _error;
  bool _changingSource = false;

  String get dllSourceDir => _settings.dllSourceDir ?? connection.dllSourceDir;

  String? get steamRoot => _settings.steamRoot;

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
