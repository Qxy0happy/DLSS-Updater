import 'package:grpc/grpc.dart';

import '../../data/daemon_api.dart';
import '../common/daemon_failure.dart';

/// How the daemon classified one item in an update run.
enum UpdateItemBucket { updated, skipped, failed }

/// The user-facing meaning of an item outcome.
///
/// The enum value is derived from `UpdateItemFinished.outcome` and the stable
/// reason token; the status message is never inspected.
enum UpdateItemKind {
  updated,
  upToDate,
  belowMinimum,
  targetMissing,
  sourceMissing,
  permissionDenied,
  versionMismatch,
  metadataStale,
  cancelled,
  internal,
  skipped,
  failed,
  unknown,
}

/// One finished item of an update run, mapped from `UpdateItemFinished`.
class UpdateItemResult {
  const UpdateItemResult({
    required this.dllId,
    required this.kind,
    required this.bucket,
    required this.reason,
    required this.backupId,
    required this.resultingVersion,
    required this.durationMs,
  });

  factory UpdateItemResult.fromProto(UpdateItemFinished message) {
    final reason = message.reason.trim();
    final kind = _kindFor(message.outcome, reason);
    return UpdateItemResult(
      dllId: message.dllId,
      kind: kind,
      bucket: _bucketFor(message.outcome, kind),
      reason: reason,
      backupId: message.backupId,
      resultingVersion: message.resultingVersion,
      durationMs: message.durationMs.toInt(),
    );
  }

  final String dllId;
  final UpdateItemKind kind;
  final UpdateItemBucket bucket;
  final String reason;
  final String backupId;
  final String resultingVersion;
  final int durationMs;

  /// English result copy for one item, selected by outcome and reason token.
  String get message => updateItemMessage(kind: kind, bucket: bucket);
}

UpdateItemKind _kindFor(UpdateOutcome outcome, String reason) {
  switch (reason) {
    case 'UP_TO_DATE':
      return UpdateItemKind.upToDate;
    case 'BELOW_MINIMUM':
      return UpdateItemKind.belowMinimum;
    case 'TARGET_MISSING':
      return UpdateItemKind.targetMissing;
    case 'SOURCE_MISSING':
      return UpdateItemKind.sourceMissing;
    case 'PERMISSION_DENIED':
      return UpdateItemKind.permissionDenied;
    case 'VERSION_MISMATCH':
      return UpdateItemKind.versionMismatch;
    case 'METADATA_STALE':
      return UpdateItemKind.metadataStale;
    case 'CANCELLED':
      return UpdateItemKind.cancelled;
    case 'INTERNAL':
      return UpdateItemKind.internal;
  }
  switch (outcome) {
    case UpdateOutcome.UPDATE_OUTCOME_UPDATED:
      return UpdateItemKind.updated;
    case UpdateOutcome.UPDATE_OUTCOME_SKIPPED:
      return UpdateItemKind.skipped;
    case UpdateOutcome.UPDATE_OUTCOME_FAILED:
      return UpdateItemKind.failed;
    case UpdateOutcome.UPDATE_OUTCOME_UNSPECIFIED:
      return UpdateItemKind.unknown;
  }
  return UpdateItemKind.unknown;
}

UpdateItemBucket _bucketFor(UpdateOutcome outcome, UpdateItemKind kind) {
  switch (outcome) {
    case UpdateOutcome.UPDATE_OUTCOME_UPDATED:
      return UpdateItemBucket.updated;
    case UpdateOutcome.UPDATE_OUTCOME_SKIPPED:
      return UpdateItemBucket.skipped;
    case UpdateOutcome.UPDATE_OUTCOME_FAILED:
      return UpdateItemBucket.failed;
    case UpdateOutcome.UPDATE_OUTCOME_UNSPECIFIED:
      break;
  }
  switch (kind) {
    case UpdateItemKind.updated:
      return UpdateItemBucket.updated;
    case UpdateItemKind.permissionDenied:
    case UpdateItemKind.versionMismatch:
    case UpdateItemKind.metadataStale:
    case UpdateItemKind.internal:
    case UpdateItemKind.failed:
      return UpdateItemBucket.failed;
    case UpdateItemKind.upToDate:
    case UpdateItemKind.belowMinimum:
    case UpdateItemKind.targetMissing:
    case UpdateItemKind.sourceMissing:
    case UpdateItemKind.cancelled:
    case UpdateItemKind.skipped:
    case UpdateItemKind.unknown:
      return UpdateItemBucket.skipped;
  }
}

/// English copy for one item result.
///
/// The reason token wins over the outcome so a skip and a rollback read
/// differently, while a successful item without a reason stays "Updated".
String updateItemMessage({
  required UpdateItemKind kind,
  required UpdateItemBucket bucket,
}) {
  switch (kind) {
    case UpdateItemKind.updated:
      return 'Updated';
    case UpdateItemKind.upToDate:
      return 'Already up to date';
    case UpdateItemKind.belowMinimum:
      return 'Skipped: below the minimum supported version';
    case UpdateItemKind.targetMissing:
      return bucket == UpdateItemBucket.failed
          ? 'Failed: the target file is missing'
          : 'Skipped: the target file is missing';
    case UpdateItemKind.sourceMissing:
      return bucket == UpdateItemBucket.failed
          ? 'Failed: no source file is available'
          : 'Skipped: no source file is available';
    case UpdateItemKind.permissionDenied:
      return 'Failed: permission denied';
    case UpdateItemKind.versionMismatch:
      return 'Rolled back: the copied file did not match the source version';
    case UpdateItemKind.metadataStale:
      return 'Updated on disk; the stored version could not be saved';
    case UpdateItemKind.cancelled:
      return 'Cancelled';
    case UpdateItemKind.internal:
      return 'Failed: internal error';
    case UpdateItemKind.skipped:
      return 'Skipped';
    case UpdateItemKind.failed:
      return 'Failed';
    case UpdateItemKind.unknown:
      return bucket == UpdateItemBucket.failed ? 'Failed' : 'Finished';
  }
}

/// Where one row of the current update run stands.
enum UpdateItemState { pending, running, finished }

/// One row of the current update run, from pending through its result.
class UpdateRunItem {
  const UpdateRunItem({
    required this.dllId,
    required this.filename,
    required this.state,
    this.result,
  });

  const UpdateRunItem.pending({required this.dllId, required this.filename})
    : state = UpdateItemState.pending,
      result = null;

  final String dllId;
  final String filename;
  final UpdateItemState state;
  final UpdateItemResult? result;

  bool get isFinished => state == UpdateItemState.finished && result != null;

  UpdateItemBucket? get bucket => result?.bucket;

  String get statusLabel => switch (state) {
    UpdateItemState.pending => 'Pending',
    UpdateItemState.running => 'Updating…',
    UpdateItemState.finished => result?.message ?? 'Finished',
  };

  UpdateRunItem running(String currentFilename) {
    return UpdateRunItem(
      dllId: dllId,
      filename: currentFilename.isEmpty ? filename : currentFilename,
      state: UpdateItemState.running,
    );
  }

  UpdateRunItem finished(UpdateItemResult itemResult) {
    return UpdateRunItem(
      dllId: dllId,
      filename: filename,
      state: UpdateItemState.finished,
      result: itemResult,
    );
  }

  /// Marks an item that the client stopped before the server sent a result.
  UpdateRunItem cancelledLocally() {
    if (isFinished) return this;
    return UpdateRunItem(
      dllId: dllId,
      filename: filename,
      state: UpdateItemState.finished,
      result: UpdateItemResult(
        dllId: dllId,
        kind: UpdateItemKind.cancelled,
        bucket: UpdateItemBucket.skipped,
        reason: 'CANCELLED',
        backupId: '',
        resultingVersion: '',
        durationMs: 0,
      ),
    );
  }
}

/// Final counters reported by the daemon (or built locally after cancel).
class UpdateRunSummary {
  const UpdateRunSummary({
    required this.succeeded,
    required this.skipped,
    required this.failed,
    required this.cancelled,
    required this.durationMs,
  });

  factory UpdateRunSummary.fromProto(UpdateFinished finished) {
    return UpdateRunSummary(
      succeeded: finished.succeeded,
      skipped: finished.skipped,
      failed: finished.failed,
      cancelled: finished.cancelled,
      durationMs: finished.durationMs.toInt(),
    );
  }

  final int succeeded;
  final int skipped;
  final int failed;
  final bool cancelled;
  final int durationMs;

  int get total => succeeded + skipped + failed;
}

/// Domain events produced by the repository for `StartUpdate`.
sealed class UpdateUpdate {
  const UpdateUpdate();
}

class UpdateRunStarted extends UpdateUpdate {
  const UpdateRunStarted(this.itemCount);

  final int itemCount;
}

class UpdateRunItemStarted extends UpdateUpdate {
  const UpdateRunItemStarted({
    required this.dllId,
    required this.filename,
    required this.index,
    required this.total,
  });

  final String dllId;
  final String filename;
  final int index;
  final int total;
}

class UpdateRunItemFinished extends UpdateUpdate {
  const UpdateRunItemFinished(this.result);

  final UpdateItemResult result;
}

class UpdateRunFinished extends UpdateUpdate {
  const UpdateRunFinished(this.summary);

  final UpdateRunSummary summary;
}

class UpdateRunFailed extends UpdateUpdate {
  const UpdateRunFailed(this.failure);

  final UpdateFailure failure;
}

/// What action the retry button of an update failure performs.
enum UpdateRetryAction { update, scan, chooseSource, retryDaemon, reload, none }

enum UpdateFailureKind {
  updateInProgress,
  sourceMissing,
  metadataStale,
  permissionDenied,
  targetMissing,
  cancelled,
  internal,
  daemonUnavailable,
  streamInterrupted,
  unknown,
}

/// A user-facing update failure with an actionable English message.
///
/// [kind] comes from `ErrorInfo.reason` (or a local condition); the status
/// message is kept only as secondary detail and is never parsed.
class UpdateFailure {
  const UpdateFailure({
    required this.kind,
    required this.message,
    required this.retry,
    this.detail,
  });

  final UpdateFailureKind kind;
  final String message;
  final UpdateRetryAction retry;
  final String? detail;

  String get retryLabel => switch (retry) {
    UpdateRetryAction.update => 'Try again',
    UpdateRetryAction.scan => 'Scan again',
    UpdateRetryAction.chooseSource => 'Choose folder',
    UpdateRetryAction.retryDaemon => 'Retry',
    UpdateRetryAction.reload => 'Refresh',
    UpdateRetryAction.none => 'Close',
  };
}

/// Thrown by the repository with an already mapped [UpdateFailure].
class UpdateException implements Exception {
  const UpdateException(this.failure);

  final UpdateFailure failure;

  @override
  String toString() => 'UpdateException(${failure.kind.name})';
}

const UpdateFailure updateStreamInterruptedFailure = UpdateFailure(
  kind: UpdateFailureKind.streamInterrupted,
  message:
      'The update ended unexpectedly before it reported a result. '
      'Try again.',
  retry: UpdateRetryAction.update,
);

const UpdateFailure updateDaemonUnavailableFailure = UpdateFailure(
  kind: UpdateFailureKind.daemonUnavailable,
  message:
      'The daemon is not reachable. Wait for it to reconnect, then '
      'try again.',
  retry: UpdateRetryAction.retryDaemon,
);

/// Maps any error from the update stream to an [UpdateFailure].
UpdateFailure updateFailureFromError(Object error) {
  if (error is UpdateException) return error.failure;
  if (isDaemonUnavailable(error)) {
    return _unavailable(error is GrpcError ? error.message : error.toString());
  }
  if (error is! GrpcError) {
    return _unavailable(error.toString());
  }
  final info = errorInfoFrom(error);
  if (info != null) {
    return updateFailureFromReason(info.reason, statusMessage: error.message);
  }
  return UpdateFailure(
    kind: UpdateFailureKind.unknown,
    message: 'The update failed for an unexpected reason.',
    detail: cleanFailureDetail(error.message),
    retry: UpdateRetryAction.update,
  );
}

/// Maps a stable `ErrorInfo.reason` token to user-facing copy.
UpdateFailure updateFailureFromReason(
  String reason, {
  String? statusMessage,
  String? failureMessage,
}) {
  final detail =
      cleanFailureDetail(statusMessage) ?? cleanFailureDetail(failureMessage);
  UpdateFailure make(
    UpdateFailureKind kind,
    String message,
    UpdateRetryAction retry,
  ) {
    return UpdateFailure(
      kind: kind,
      message: message,
      detail: detail,
      retry: retry,
    );
  }

  switch (reason) {
    case 'UPDATE_IN_PROGRESS':
      return make(
        UpdateFailureKind.updateInProgress,
        'Another update is already running. Wait for it to finish, then '
        'try again.',
        UpdateRetryAction.update,
      );
    case 'SOURCE_MISSING':
      return make(
        UpdateFailureKind.sourceMissing,
        'The DLL source folder is missing or does not contain the required '
        'files. Choose the folder again, then retry.',
        UpdateRetryAction.chooseSource,
      );
    case 'METADATA_STALE':
      return make(
        UpdateFailureKind.metadataStale,
        'The update changed files on disk, but the stored library data is '
        'out of date. Scan again to refresh the versions.',
        UpdateRetryAction.scan,
      );
    case 'PERMISSION_DENIED':
      return make(
        UpdateFailureKind.permissionDenied,
        'Some files could not be written. Check the library permissions and '
        'try again.',
        UpdateRetryAction.update,
      );
    case 'TARGET_MISSING':
      return make(
        UpdateFailureKind.targetMissing,
        'A target file disappeared before it could be updated. Scan again '
        'to refresh the library.',
        UpdateRetryAction.scan,
      );
    case 'CANCELLED':
      return make(
        UpdateFailureKind.cancelled,
        'The update was cancelled before it finished.',
        UpdateRetryAction.update,
      );
    case 'INTERNAL':
      return make(
        UpdateFailureKind.internal,
        'The daemon hit an internal error. Try again; if it keeps happening, '
        'restart the app.',
        UpdateRetryAction.update,
      );
    default:
      return make(
        UpdateFailureKind.unknown,
        'The update failed for an unexpected reason.',
        UpdateRetryAction.update,
      );
  }
}

UpdateFailure _unavailable(String? message) {
  return UpdateFailure(
    kind: UpdateFailureKind.daemonUnavailable,
    message:
        'The daemon is not reachable. Wait for it to reconnect, then '
        'try again.',
    detail: cleanFailureDetail(message),
    retry: UpdateRetryAction.retryDaemon,
  );
}
