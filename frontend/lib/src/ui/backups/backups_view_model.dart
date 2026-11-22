import 'package:flutter/foundation.dart';

import 'backups_repository.dart';
import 'models.dart';

/// Backups state: the current query result, section grouping, and the
/// confirmed restore/delete operations.
class BackupsViewModel extends ChangeNotifier {
  BackupsViewModel(this._repository);

  final BackupsRepository _repository;

  List<BackupEntry> _entries = const [];
  bool _loading = false;
  bool _hasLoaded = false;
  bool _includeHistory = false;
  BackupFailure? _loadFailure;
  BackupFailure? _operationFailure;
  BackupOperation? _failedOperation;
  BackupOperation? _runningOperation;
  String? _busyBackupId;
  String? _lastResult;
  bool _disposed = false;

  bool get loading => _loading;

  bool get hasLoaded => _hasLoaded;

  bool get includeHistory => _includeHistory;

  bool get busy => _busyBackupId != null;

  String? get busyBackupId => _busyBackupId;

  BackupOperation? get runningOperation => _runningOperation;

  /// Failure that prevented the list from loading at all.
  BackupFailure? get loadFailure => _loadFailure;

  /// Failure of the last confirmed restore or delete.
  BackupFailure? get operationFailure => _operationFailure;

  BackupOperation? get failedOperation => _failedOperation;

  String? get lastResult => _lastResult;

  /// Current query result, newest first.
  List<BackupEntry> get entries => List.unmodifiable(_entries);

  BackupsSections get sections {
    final active = <String, List<BackupEntry>>{};
    final orphans = <String, List<BackupEntry>>{};
    final history = <String, List<BackupEntry>>{};
    final names = <String, String>{};

    for (final entry in _entries) {
      final key = entry.gameId.isEmpty ? entry.gameName : entry.gameId;
      names.putIfAbsent(key, () => entry.gameName);
      if (!entry.isActive) {
        history.putIfAbsent(key, () => []).add(entry);
      } else if (!entry.targetExists) {
        orphans.putIfAbsent(key, () => []).add(entry);
      } else {
        active.putIfAbsent(key, () => []).add(entry);
      }
    }

    List<BackupGroup> groups(Map<String, List<BackupEntry>> grouped) {
      return [
        for (final item in grouped.entries)
          BackupGroup(
            gameId: item.key,
            gameName: names[item.key] ?? item.key,
            backups: List.unmodifiable(item.value),
          ),
      ];
    }

    return BackupsSections(
      active: groups(active),
      orphans: groups(orphans),
      history: groups(history),
    );
  }

  bool get isEmpty => sections.isEmpty;

  /// Loads the list. The first page is active backups only; history is
  /// requested explicitly with `includeInactive`.
  Future<void> load({bool? includeInactive}) async {
    if (includeInactive != null) _includeHistory = includeInactive;
    _loading = true;
    _loadFailure = null;
    _operationFailure = null;
    _notify();
    try {
      _entries = await _repository.list(includeInactive: _includeHistory);
    } on BackupException catch (error) {
      _entries = const [];
      _loadFailure = error.failure;
    } catch (_) {
      _entries = const [];
      _loadFailure = const BackupFailure(BackupFailureReason.unknown);
    } finally {
      _loading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  Future<void> retry() => load();

  Future<void> toggleHistory() async {
    if (_loading) return;
    _includeHistory = !_includeHistory;
    await load();
  }

  void dismissOperationFailure() {
    _operationFailure = null;
    _failedOperation = null;
    _notify();
  }

  /// Restores after the view's confirmation dialog. On success the list is
  /// requeried with inactive records so the row moves into history.
  Future<void> restoreBackup(BackupEntry entry) async {
    if (busy) return;
    _begin(BackupOperation.restore, entry);
    try {
      await _repository.restore(entry.id);
      _includeHistory = true;
      await _reloadInPlace();
      _lastResult = 'Restored ${entry.dllFilename}.';
    } on BackupException catch (error) {
      _operationFailure = error.failure;
      _failedOperation = BackupOperation.restore;
    } catch (_) {
      _operationFailure = const BackupFailure(BackupFailureReason.unknown);
      _failedOperation = BackupOperation.restore;
    } finally {
      _end();
    }
  }

  /// Deletes after the view's confirmation dialog and refreshes the list.
  Future<void> deleteBackup(BackupEntry entry) async {
    if (busy) return;
    _begin(BackupOperation.delete, entry);
    try {
      await _repository.delete(entry.id);
      await _reloadInPlace();
      _lastResult = 'Deleted the backup for ${entry.dllFilename}.';
    } on BackupException catch (error) {
      _operationFailure = error.failure;
      _failedOperation = BackupOperation.delete;
    } catch (_) {
      _operationFailure = const BackupFailure(BackupFailureReason.unknown);
      _failedOperation = BackupOperation.delete;
    } finally {
      _end();
    }
  }

  /// Refresh that keeps the current history choice and the operation banner;
  /// used by the post-restore/post-delete requery.
  Future<void> _reloadInPlace() async {
    _loading = true;
    _notify();
    try {
      _entries = await _repository.list(includeInactive: _includeHistory);
      _loadFailure = null;
    } on BackupException catch (error) {
      _entries = const [];
      _loadFailure = error.failure;
    } catch (_) {
      _entries = const [];
      _loadFailure = const BackupFailure(BackupFailureReason.unknown);
    } finally {
      _loading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  void _begin(BackupOperation operation, BackupEntry entry) {
    _busyBackupId = entry.id;
    _runningOperation = operation;
    _operationFailure = null;
    _failedOperation = null;
    _lastResult = null;
    _notify();
  }

  void _end() {
    _busyBackupId = null;
    _runningOperation = null;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
