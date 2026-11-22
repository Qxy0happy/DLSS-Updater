import 'package:grpc/grpc.dart';

import '../../data/daemon_api.dart';
import '../common/daemon_failure.dart';
import '../common/dll_catalog.dart';

/// One known-technology DLL inside a game, mapped from `GameDLL`.
class GameDll {
  const GameDll({
    required this.id,
    required this.gameId,
    required this.type,
    required this.filename,
    required this.path,
    required this.currentVersion,
    required this.sourceVersion,
    required this.exists,
    this.missingAt,
  });

  factory GameDll.fromProto(GameDLL dll) {
    return GameDll(
      id: dll.id,
      gameId: dll.gameId,
      type: dll.dllType,
      filename: dll.filename,
      path: dll.path,
      currentVersion: dll.currentVersion,
      sourceVersion: dll.sourceVersion,
      exists: dll.exists,
      missingAt: dll.hasMissingAt() ? dll.missingAt.toDateTime() : null,
    );
  }

  final String id;
  final String gameId;
  final String type;
  final String filename;
  final String path;
  final String currentVersion;
  final String sourceVersion;
  final bool exists;
  final DateTime? missingAt;

  /// Human-readable name for the catalog id, falling back to the id itself.
  String get typeLabel => dllTypeLabel(type);

  bool get hasSource => sourceVersion.isNotEmpty;

  bool get missing => !exists || missingAt != null;
}

/// A scanned game with its DLLs.
class GameSummary {
  const GameSummary({
    required this.id,
    required this.appId,
    required this.name,
    required this.installPath,
    required this.libraryPath,
    required this.dlls,
  });

  factory GameSummary.fromProto(Game game) {
    final dlls = [for (final dll in game.dlls) GameDll.fromProto(dll)]
      ..sort((a, b) {
        final byType = a.typeLabel.compareTo(b.typeLabel);
        return byType != 0 ? byType : a.filename.compareTo(b.filename);
      });
    return GameSummary(
      id: game.id,
      appId: game.appId,
      name: game.name,
      installPath: game.installPath,
      libraryPath: game.libraryPath,
      dlls: dlls,
    );
  }

  final String id;
  final int appId;
  final String name;
  final String installPath;
  final String libraryPath;
  final List<GameDll> dlls;

  int get dllCount => dlls.length;
}

/// Counters and current location of a running scan. `sourceIndex` counts
/// ScanSources (a Steam source counts once for all its libraries); `path` is
/// the Steam library or custom folder currently being traversed.
class ScanProgress {
  const ScanProgress({
    this.path = '',
    this.sourceIndex = 0,
    this.sourceCount = 0,
    this.currentGame = '',
    this.gamesFound = 0,
    this.dllsFound = 0,
  });

  factory ScanProgress.fromProto(ScanLibraryProgress progress) {
    return ScanProgress(
      path: progress.libraryPath,
      sourceIndex: progress.libraryIndex,
      sourceCount: progress.libraryCount,
      currentGame: progress.currentGame,
      gamesFound: progress.gamesFound,
      dllsFound: progress.dllsFound,
    );
  }

  /// The Steam library or custom folder currently being traversed. Several
  /// libraries of one Steam source share a single source index.
  final String path;
  final int sourceIndex;
  final int sourceCount;
  final String currentGame;
  final int gamesFound;
  final int dllsFound;

  /// Fraction of the scan that is done, or null while the source count is
  /// still unknown.
  double? get fraction {
    if (sourceCount <= 0) return null;
    final done = (sourceIndex - 1).clamp(0, sourceCount);
    return done / sourceCount;
  }
}

/// Final counters reported by the daemon.
class ScanSummary {
  const ScanSummary({
    required this.gameCount,
    required this.dllCount,
    required this.cancelled,
    required this.durationMs,
  });

  factory ScanSummary.fromProto(ScanFinished finished) {
    return ScanSummary(
      gameCount: finished.gameCount,
      dllCount: finished.dllCount,
      cancelled: finished.cancelled,
      durationMs: finished.durationMs.toInt(),
    );
  }

  final int gameCount;
  final int dllCount;
  final bool cancelled;
  final int durationMs;
}

/// A non-fatal scan problem. The scan continued; this is not necessarily a
/// read failure (it can also be an unsupported source, an overlap or a folder
/// without known DLLs).
class ScanWarningInfo {
  const ScanWarningInfo({required this.path, required this.message});

  factory ScanWarningInfo.fromProto(ScanWarning warning) {
    return ScanWarningInfo(path: warning.path, message: warning.message);
  }

  final String path;
  final String message;
}

/// Domain events produced by the repository for `StartScan`.
sealed class ScanUpdate {
  const ScanUpdate();
}

class ScanStartedUpdate extends ScanUpdate {
  const ScanStartedUpdate(this.steamRoot);

  final String steamRoot;
}

class ScanLibraryUpdate extends ScanUpdate {
  const ScanLibraryUpdate(this.progress);

  final ScanProgress progress;
}

class GameFoundUpdate extends ScanUpdate {
  const GameFoundUpdate(this.game);

  final GameSummary game;
}

class ScanFinishedUpdate extends ScanUpdate {
  const ScanFinishedUpdate(this.summary);

  final ScanSummary summary;
}

class ScanFailedUpdate extends ScanUpdate {
  const ScanFailedUpdate(this.failure);

  final GamesFailure failure;
}

class ScanWarningUpdate extends ScanUpdate {
  const ScanWarningUpdate(this.warning);

  final ScanWarningInfo warning;
}

/// The operation a failure came from; it selects the relevant retry.
enum GamesRequestKind { scan, library }

enum GamesFailureKind {
  scanRootInvalid,
  scanInProgress,
  permissionDenied,
  cancelled,
  metadataStale,
  internal,
  daemonUnavailable,
  streamInterrupted,
  noSources,
  settingsUnavailable,
  unknown,
}

/// What the retry button of an error does.
enum GamesRetryAction { scan, reload, chooseRoot, chooseSource, retryDaemon }

/// A user-facing failure with an actionable English message.
///
/// [kind] comes from `google.rpc.ErrorInfo.reason` (or a local condition);
/// the status message is only kept as secondary detail, never parsed.
class GamesFailure {
  const GamesFailure({
    required this.kind,
    required this.message,
    required this.retry,
    this.detail,
  });

  final GamesFailureKind kind;
  final String message;
  final GamesRetryAction retry;
  final String? detail;

  String get retryLabel => switch (retry) {
    GamesRetryAction.scan => 'Scan again',
    GamesRetryAction.reload => 'Try again',
    GamesRetryAction.chooseRoot => 'Choose folder',
    GamesRetryAction.chooseSource => 'Choose folder',
    GamesRetryAction.retryDaemon => 'Retry',
  };
}

/// Thrown by the repository with an already mapped [GamesFailure].
class GamesException implements Exception {
  const GamesException(this.failure);

  final GamesFailure failure;

  @override
  String toString() => 'GamesException(${failure.kind.name})';
}

/// Maps any error from the daemon seam to a [GamesFailure].
GamesFailure failureFromError(
  Object error, {
  required GamesRequestKind request,
}) {
  if (error is GamesException) return error.failure;
  if (isDaemonUnavailable(error)) {
    return _daemonUnavailable(
      error is GrpcError ? error.message : error.toString(),
    );
  }
  if (error is! GrpcError) {
    return _daemonUnavailable(error.toString());
  }
  final info = errorInfoFrom(error);
  if (info != null) {
    return failureFromReason(
      info.reason,
      request: request,
      statusMessage: error.message,
    );
  }
  return GamesFailure(
    kind: GamesFailureKind.unknown,
    message: 'The daemon returned an unexpected error.',
    detail: cleanFailureDetail(error.message),
    retry: _retryFor(request),
  );
}

/// Maps a stable `ErrorInfo.reason` token to user-facing copy.
GamesFailure failureFromReason(
  String reason, {
  required GamesRequestKind request,
  String? statusMessage,
  String? failureMessage,
}) {
  final detail =
      cleanFailureDetail(statusMessage) ?? cleanFailureDetail(failureMessage);
  GamesFailure make(
    GamesFailureKind kind,
    String message,
    GamesRetryAction retry,
  ) {
    return GamesFailure(
      kind: kind,
      message: message,
      detail: detail,
      retry: retry,
    );
  }

  switch (reason) {
    case 'SCAN_ROOT_INVALID':
      return make(
        GamesFailureKind.scanRootInvalid,
        'One or more scan folders cannot be read. Choose a folder that exists '
        'and is readable.',
        GamesRetryAction.chooseSource,
      );
    case 'SCAN_IN_PROGRESS':
      return make(
        GamesFailureKind.scanInProgress,
        'A scan is already running. Wait for it to finish, then try again.',
        _retryFor(request),
      );
    case 'PERMISSION_DENIED':
      return make(
        GamesFailureKind.permissionDenied,
        'Part of the selected folder could not be read. Check the folder '
        'permissions and try again.',
        _retryFor(request),
      );
    case 'CANCELLED':
      return make(
        GamesFailureKind.cancelled,
        'The scan was cancelled before it finished.',
        _retryFor(request),
      );
    case 'METADATA_STALE':
      return make(
        GamesFailureKind.metadataStale,
        'The stored game data is out of date. Run a scan to refresh it.',
        GamesRetryAction.scan,
      );
    case 'INTERNAL':
      return make(
        GamesFailureKind.internal,
        'The daemon hit an internal error. Try again; if it keeps happening, '
        'restart the app.',
        _retryFor(request),
      );
    default:
      return make(
        GamesFailureKind.unknown,
        'The daemon returned an unexpected error.',
        _retryFor(request),
      );
  }
}

const GamesFailure streamInterruptedFailure = GamesFailure(
  kind: GamesFailureKind.streamInterrupted,
  message:
      'The scan ended unexpectedly before it reported a result. '
      'Try again.',
  retry: GamesRetryAction.scan,
);

const GamesFailure noSourcesFailure = GamesFailure(
  kind: GamesFailureKind.noSources,
  message:
      'Choose your Steam folder or add a custom game folder before scanning.',
  retry: GamesRetryAction.chooseRoot,
);

const GamesFailure settingsFailure = GamesFailure(
  kind: GamesFailureKind.settingsUnavailable,
  message: 'The scan sources could not be saved. Try again.',
  retry: GamesRetryAction.chooseSource,
);

GamesRetryAction _retryFor(GamesRequestKind request) {
  return request == GamesRequestKind.scan
      ? GamesRetryAction.scan
      : GamesRetryAction.reload;
}

GamesFailure _daemonUnavailable(String? message) {
  return GamesFailure(
    kind: GamesFailureKind.daemonUnavailable,
    message:
        'The daemon is not reachable. Wait for it to reconnect, then '
        'try again.',
    detail: cleanFailureDetail(message),
    retry: GamesRetryAction.retryDaemon,
  );
}
