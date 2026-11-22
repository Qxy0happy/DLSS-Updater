import 'package:grpc/grpc.dart';

import '../../data/daemon_api.dart';
import '../common/daemon_failure.dart';
import 'models.dart';

/// Thrown by [BackupsRepository] with the failure category already translated.
class BackupException implements Exception {
  const BackupException(this.failure);

  final BackupFailure failure;

  @override
  String toString() => 'BackupException(${failure.reason.name})';
}

/// Translates the `Backup` service into domain types.
class BackupsRepository {
  BackupsRepository(this._api);

  final DaemonApi _api;

  Future<List<BackupEntry>> list({bool includeInactive = false}) async {
    try {
      final response = await _api.listBackups(
        ListBackupsRequest(includeInactive: includeInactive),
      );
      return [for (final record in response.backups) _toEntry(record)];
    } on GrpcError catch (error) {
      throw BackupException(_failureFor(error));
    }
  }

  Future<void> restore(String backupId) async {
    try {
      await _api.restoreBackup(RestoreBackupRequest(backupId: backupId));
    } on GrpcError catch (error) {
      throw BackupException(_failureFor(error));
    }
  }

  Future<void> delete(String backupId) async {
    try {
      await _api.deleteBackup(DeleteBackupRequest(backupId: backupId));
    } on GrpcError catch (error) {
      throw BackupException(_failureFor(error));
    }
  }

  BackupEntry _toEntry(BackupRecord record) {
    return BackupEntry(
      id: record.id,
      gameId: record.gameId,
      gameName: record.gameName,
      dllFilename: record.dllFilename,
      dllType: record.dllType,
      backupPath: record.backupPath,
      originalVersion: record.originalVersion,
      sizeBytes: record.sizeBytes.toInt(),
      createdAt: record.hasCreatedAt()
          ? record.createdAt.toDateTime()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isActive: record.isActive,
      targetExists: record.targetExists,
      targetPath: targetPathForBackup(record.backupPath),
      restoredAt: record.hasRestoredAt()
          ? record.restoredAt.toDateTime()
          : null,
    );
  }

  /// Branch on the stable `ErrorInfo.reason`; never on the status message.
  BackupFailure _failureFor(GrpcError error) {
    final info = errorInfoFrom(error);
    if (info != null) {
      final reason = switch (info.reason) {
        'BACKUP_MISSING' => BackupFailureReason.backupMissing,
        'BACKUP_CORRUPT' => BackupFailureReason.backupCorrupt,
        'TARGET_FOLDER_MISSING' => BackupFailureReason.targetFolderMissing,
        'PERMISSION_DENIED' => BackupFailureReason.permissionDenied,
        'METADATA_STALE' => BackupFailureReason.metadataStale,
        _ => null,
      };
      if (reason != null) return BackupFailure(reason);
    }
    if (isDaemonUnavailable(error)) {
      return const BackupFailure(BackupFailureReason.daemonUnavailable);
    }
    return const BackupFailure(BackupFailureReason.unknown);
  }
}
