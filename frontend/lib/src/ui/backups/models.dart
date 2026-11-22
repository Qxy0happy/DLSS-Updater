/// Domain types for the Backups destination.
///
/// The repository converts `dlss.v1.BackupRecord` into these types so the view
/// model and views never depend on generated messages.
library;

/// A `.dlsss` backup row as the Backups view presents it.
class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.dllFilename,
    required this.dllType,
    required this.backupPath,
    required this.originalVersion,
    required this.sizeBytes,
    required this.createdAt,
    required this.isActive,
    required this.targetExists,
    required this.targetPath,
    this.restoredAt,
  });

  final String id;
  final String gameId;
  final String gameName;
  final String dllFilename;
  final String dllType;
  final String backupPath;
  final String originalVersion;
  final int sizeBytes;
  final DateTime createdAt;
  final bool isActive;
  final bool targetExists;

  /// Original DLL location, recovered from the `.dlsss` path.
  final String targetPath;

  /// Set when this backup was restored.
  final DateTime? restoredAt;

  /// Active backup whose target DLL disappeared from disk.
  bool get isOrphan => isActive && !targetExists;

  /// Whether the backup was put back in place at least once.
  bool get isRestored => restoredAt != null;
}

/// Stable failure categories the Backups UI branches on.
enum BackupFailureReason {
  backupMissing,
  backupCorrupt,
  targetFolderMissing,
  permissionDenied,
  metadataStale,
  daemonUnavailable,
  unknown,
}

/// Actionable English copy, selected by [BackupFailureReason] only.
class BackupFailureCopy {
  const BackupFailureCopy._();

  static const String backupMissing =
      'The backup file is missing. Refresh the list; it may have been deleted '
      'already.';
  static const String backupCorrupt =
      'The backup file is damaged or no longer matches its record. Delete it '
      'and create a new backup by updating the DLL again.';
  static const String targetFolderMissing =
      'The target folder no longer exists. Reinstall the game or rescan your '
      'library, then try again.';
  static const String permissionDenied =
      'Permission denied. Check that the game folder is writable, then try '
      'again.';
  static const String metadataStale =
      'The library database is out of date. Rescan your Steam library, then '
      'try again.';
  static const String daemonUnavailable =
      'The daemon is not available. Wait for it to reconnect, then try again.';
  static const String unknown = 'The backup operation failed. Try again.';

  static String messageFor(BackupFailureReason reason) {
    return switch (reason) {
      BackupFailureReason.backupMissing => backupMissing,
      BackupFailureReason.backupCorrupt => backupCorrupt,
      BackupFailureReason.targetFolderMissing => targetFolderMissing,
      BackupFailureReason.permissionDenied => permissionDenied,
      BackupFailureReason.metadataStale => metadataStale,
      BackupFailureReason.daemonUnavailable => daemonUnavailable,
      BackupFailureReason.unknown => unknown,
    };
  }
}

/// A translated daemon failure.
class BackupFailure {
  const BackupFailure(this.reason);

  final BackupFailureReason reason;

  String get userMessage => BackupFailureCopy.messageFor(reason);
}

/// Which operation failed, used for the banner title.
enum BackupOperation { restore, delete }

/// A game's backups, in response order.
class BackupGroup {
  const BackupGroup({
    required this.gameId,
    required this.gameName,
    required this.backups,
  });

  final String gameId;
  final String gameName;
  final List<BackupEntry> backups;
}

/// The three sections of the Backups destination.
class BackupsSections {
  const BackupsSections({
    this.active = const [],
    this.orphans = const [],
    this.history = const [],
  });

  final List<BackupGroup> active;
  final List<BackupGroup> orphans;
  final List<BackupGroup> history;

  bool get isEmpty => active.isEmpty && orphans.isEmpty && history.isEmpty;

  int get activeCount =>
      active.fold(0, (count, group) => count + group.backups.length);
}

/// Rebuilds the original DLL path from the `.dlsss` backup path.
String targetPathForBackup(String backupPath) {
  const suffix = '.dlsss';
  if (backupPath.toLowerCase().endsWith(suffix)) {
    final base = backupPath.substring(0, backupPath.length - suffix.length);
    return '$base.dll';
  }
  return backupPath;
}

/// Compact file size, mirroring the old app's B/KB/MB labels.
String formatBackupSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(1)} GB';
}

/// Deterministic UTC timestamp: `2026-01-02 15:04 UTC`.
String formatBackupTimestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)} UTC';
}
