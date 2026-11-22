import '../../data/daemon_api.dart';
import '../../data/daemon_stream.dart';
import 'models.dart';
import 'update_models.dart';

/// A running scan. [events] are domain events; [cancel] cancels the RPC, not
/// just the local subscription.
class ScanSession {
  const ScanSession({required this.events, required this.cancel});

  final Stream<ScanUpdate> events;
  final Future<void> Function() cancel;
}

/// A running update. Cancelling cancels the RPC immediately; the server stops
/// between items and late events are not needed to close the local run.
class UpdateSession {
  const UpdateSession({required this.events, required this.cancel});

  final Stream<UpdateUpdate> events;
  final Future<void> Function() cancel;
}

/// Maps the generated `dlss.v1` models onto the Games domain models.
class GamesRepository {
  GamesRepository(this._api);

  final DaemonApi _api;

  Future<List<GameSummary>> listGames() async {
    try {
      final response = await _api.listGames(ListGamesRequest());
      return [for (final game in response.games) GameSummary.fromProto(game)];
    } catch (error) {
      throw GamesException(
        failureFromError(error, request: GamesRequestKind.library),
      );
    }
  }

  /// Re-reads one game after an update so the rows show stored versions.
  Future<GameSummary> getGame(String gameId) async {
    try {
      final game = await _api.getGame(GetGameRequest(gameId: gameId));
      return GameSummary.fromProto(game);
    } catch (error) {
      throw GamesException(
        failureFromError(error, request: GamesRequestKind.library),
      );
    }
  }

  ScanSession startScan({
    String? steamRoot,
    List<String> customFolders = const [],
  }) {
    final sources = <ScanSource>[
      if (steamRoot != null && steamRoot.isNotEmpty)
        ScanSource(steam: SteamSource(root: steamRoot)),
      for (final path in customFolders)
        if (path.isNotEmpty)
          ScanSource(customFolder: CustomFolderSource(path: path)),
    ];
    final DaemonStream<ScanEvent> stream;
    try {
      stream = _api.startScan(StartScanRequest(sources: sources));
    } catch (error) {
      throw GamesException(
        failureFromError(error, request: GamesRequestKind.scan),
      );
    }
    return ScanSession(
      // A plain map/where chain keeps cancellation prompt: cancelling this
      // subscription cancels the gRPC call's stream immediately instead of
      // waiting for an `await for` loop to observe the cancellation.
      events: stream.events
          .map(_mapScanEvent)
          .where((update) => update != null)
          .cast<ScanUpdate>(),
      cancel: stream.cancel,
    );
  }

  ScanUpdate? _mapScanEvent(ScanEvent event) {
    switch (event.whichEvent()) {
      case ScanEvent_Event.started:
        return ScanStartedUpdate(event.started.steamRoot);
      case ScanEvent_Event.libraryProgress:
        return ScanLibraryUpdate(ScanProgress.fromProto(event.libraryProgress));
      case ScanEvent_Event.gameFound:
        return GameFoundUpdate(GameSummary.fromProto(event.gameFound));
      case ScanEvent_Event.finished:
        return ScanFinishedUpdate(ScanSummary.fromProto(event.finished));
      case ScanEvent_Event.failed:
        return ScanFailedUpdate(
          failureFromReason(
            event.failed.reason,
            request: GamesRequestKind.scan,
            failureMessage: event.failed.message,
          ),
        );
      case ScanEvent_Event.warning:
        return ScanWarningUpdate(ScanWarningInfo.fromProto(event.warning));
      case ScanEvent_Event.notSet:
        return null;
    }
  }

  /// Starts an update for [dllIds] in the given order.
  UpdateSession startUpdate(List<String> dllIds) {
    final DaemonStream<UpdateEvent> stream;
    try {
      stream = _api.startUpdate(StartUpdateRequest(dllIds: dllIds));
    } catch (error) {
      throw UpdateException(updateFailureFromError(error));
    }
    return UpdateSession(
      // The map/where chain keeps cancellation prompt, as with scans.
      events: stream.events
          .map(_mapUpdateEvent)
          .where((update) => update != null)
          .cast<UpdateUpdate>(),
      cancel: stream.cancel,
    );
  }

  UpdateUpdate? _mapUpdateEvent(UpdateEvent event) {
    switch (event.whichEvent()) {
      case UpdateEvent_Event.started:
        return UpdateRunStarted(event.started.itemCount);
      case UpdateEvent_Event.itemStarted:
        final started = event.itemStarted;
        return UpdateRunItemStarted(
          dllId: started.dllId,
          filename: started.filename,
          index: started.index,
          total: started.total,
        );
      case UpdateEvent_Event.itemFinished:
        return UpdateRunItemFinished(
          UpdateItemResult.fromProto(event.itemFinished),
        );
      case UpdateEvent_Event.finished:
        return UpdateRunFinished(UpdateRunSummary.fromProto(event.finished));
      case UpdateEvent_Event.failed:
        return UpdateRunFailed(
          updateFailureFromReason(
            event.failed.reason,
            failureMessage: event.failed.message,
          ),
        );
      case UpdateEvent_Event.notSet:
        return null;
    }
  }
}
