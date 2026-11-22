import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/daemon_connection.dart';
import '../settings/settings_view_model.dart';
import 'games_repository.dart';
import 'models.dart';
import 'update_models.dart';

/// Where the current update run stands.
enum UpdatePhase { idle, running, cancelling, completed, failed }

/// Owns one update run: the per-row states, the event subscription, the
/// cancellation handshake and the summary.
///
/// GamesViewModel keeps the scan state and the selection and delegates the
/// second state machine here. The controller never talks to the view; it asks
/// its owner two questions through callbacks: whether a run is currently
/// allowed, and what to do for a "scan again" retry.
class UpdateRunController extends ChangeNotifier {
  UpdateRunController({
    required this.repository,
    required this.settings,
    this.connection,
    required this.isBlocked,
    required this.onScanRequested,
    required this.onGameRefreshed,
  });

  final GamesRepository repository;
  final SettingsViewModel settings;
  final DaemonConnection? connection;

  /// Whether a scan, a daemon outage or another update currently forbids a run.
  final bool Function() isBlocked;

  /// Retry hook for [UpdateRetryAction.scan]; scoped by GamesViewModel.
  final Future<void> Function() onScanRequested;

  /// Receives a freshly read game after a run so the owner can merge it.
  final void Function(GameSummary game) onGameRefreshed;

  final Stopwatch _stopwatch = Stopwatch();

  List<UpdateRunItem> _items = const [];
  UpdatePhase _phase = UpdatePhase.idle;
  UpdateRunSummary? _summary;
  UpdateFailure? _failure;
  String? _currentDllId;
  int _currentIndex = 0;
  int _total = 0;
  GameSummary? _lastGame;
  List<String> _lastDllIds = const [];
  UpdateSession? _session;
  StreamSubscription<UpdateUpdate>? _subscription;
  bool _ignoreEvents = false;
  int _generation = 0;

  UpdatePhase get phase => _phase;

  List<UpdateRunItem> get items => List.unmodifiable(_items);

  Map<String, UpdateRunItem> get itemsByDllId => {
    for (final item in _items) item.dllId: item,
  };

  UpdateRunSummary? get summary => _summary;

  UpdateFailure? get failure => _failure;

  bool get updating =>
      _phase == UpdatePhase.running || _phase == UpdatePhase.cancelling;

  bool get cancelling => _phase == UpdatePhase.cancelling;

  UpdateRunItem? get currentItem {
    final id = _currentDllId;
    if (id == null) return null;
    for (final item in _items) {
      if (item.dllId == id) return item;
    }
    return null;
  }

  int get totalCount => _total > 0 ? _total : _items.length;

  int get currentIndex => _currentIndex;

  int get doneCount => _items.where((item) => item.isFinished).length;

  int get updatedCount => _countBucket(UpdateItemBucket.updated);

  int get skippedCount => _countBucket(UpdateItemBucket.skipped);

  int get failedCount => _countBucket(UpdateItemBucket.failed);

  /// Starts one run for [targets], in the order the detail panel displays them.
  Future<void> start(GameSummary game, List<GameDll> targets) async {
    if (isBlocked() || targets.isEmpty) return;

    _lastGame = game;
    _lastDllIds = [for (final dll in targets) dll.id];
    _generation += 1;
    _ignoreEvents = false;
    _summary = null;
    _failure = null;
    _currentDllId = null;
    _currentIndex = 0;
    _total = targets.length;
    _items = [
      for (final dll in targets)
        UpdateRunItem.pending(dllId: dll.id, filename: dll.filename),
    ];
    _phase = UpdatePhase.running;
    _stopwatch
      ..reset()
      ..start();
    notifyListeners();

    try {
      final session = repository.startUpdate(_lastDllIds);
      if (!updating || _ignoreEvents) {
        unawaited(session.cancel());
        return;
      }
      _session = session;
      _subscription = session.events.listen(
        _onEvent,
        onError: _onError,
        onDone: _onDone,
      );
    } on UpdateException catch (error) {
      _fail(error.failure);
    } catch (error) {
      _fail(updateFailureFromError(error));
    }
  }

  /// Cancels the run without waiting for its remaining server events.
  ///
  /// Finished rows keep their results; unfinished rows become cancelled. The
  /// summary counts the results the server already sent, and the game is
  /// re-read from the repository afterwards.
  Future<void> cancel() async {
    if (_phase != UpdatePhase.running) return;
    _phase = UpdatePhase.cancelling;
    _ignoreEvents = true;

    final session = _session;
    final subscription = _subscription;
    _session = null;
    _subscription = null;
    // Cancel the RPC immediately: the summary must not wait for the server.
    unawaited(subscription?.cancel());
    unawaited(_cancelSession(session));

    _stopwatch.stop();
    final updated = updatedCount;
    final skipped = skippedCount;
    final failed = failedCount;
    _items = [for (final item in _items) item.cancelledLocally()];
    _summary = UpdateRunSummary(
      succeeded: updated,
      skipped: skipped,
      failed: failed,
      cancelled: true,
      durationMs: _stopwatch.elapsedMilliseconds,
    );
    _phase = UpdatePhase.completed;
    _currentDllId = null;
    _currentIndex = 0;
    notifyListeners();

    await _refreshGame();
  }

  /// Re-runs what the failure suggests; the Close button dismisses it.
  Future<void> retry() async {
    final current = _failure;
    if (current == null) return;
    switch (current.retry) {
      case UpdateRetryAction.update:
        await _retryLastRun();
      case UpdateRetryAction.scan:
        _dismissState();
        await onScanRequested();
      case UpdateRetryAction.chooseSource:
        try {
          await settings.chooseDllSource();
        } catch (_) {
          return;
        }
        await _retryLastRun();
      case UpdateRetryAction.retryDaemon:
        await connection?.retry();
        await _retryLastRun();
      case UpdateRetryAction.reload:
        await _refreshGame();
      case UpdateRetryAction.none:
        break;
    }
  }

  /// Removes the run-level error and returns the detail panel to idle.
  void dismissFailure() {
    if (_failure == null) return;
    _dismissState();
    notifyListeners();
  }

  Future<void> _retryLastRun() async {
    final game = _lastGame;
    if (game == null) return;
    final byId = {for (final dll in game.dlls) dll.id: dll};
    final targets = [
      for (final id in _lastDllIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (targets.isEmpty) return;
    await start(game, targets);
  }

  Future<void> _cancelSession(UpdateSession? session) async {
    try {
      await session?.cancel();
    } catch (_) {
      // Cancellation races are expected; the local summary still applies.
    }
  }

  void _onEvent(UpdateUpdate update) {
    if (_ignoreEvents || _phase != UpdatePhase.running) return;
    switch (update) {
      case UpdateRunStarted(:final itemCount):
        if (itemCount > 0) _total = itemCount;
      case UpdateRunItemStarted(
        :final dllId,
        :final filename,
        :final index,
        :final total,
      ):
        if (total > 0) _total = total;
        _currentIndex = index;
        _currentDllId = dllId;
        _replaceItem(dllId, (item) => item.running(filename));
      case UpdateRunItemFinished(:final result):
        _currentDllId = result.dllId == _currentDllId ? null : _currentDllId;
        _replaceItem(result.dllId, (item) {
          return UpdateRunItem(
            dllId: item.dllId,
            filename: item.filename,
            state: UpdateItemState.finished,
            result: result,
          );
        });
      case UpdateRunFinished(:final summary):
        _stopwatch.stop();
        _summary = summary;
        _phase = UpdatePhase.completed;
        _currentDllId = null;
        _currentIndex = 0;
        _session = null;
        _subscription = null;
        notifyListeners();
        unawaited(_refreshGame());
        return;
      case UpdateRunFailed(:final failure):
        _fail(failure);
        return;
    }
    notifyListeners();
  }

  void _onError(Object error) {
    if (_ignoreEvents ||
        _phase == UpdatePhase.completed ||
        _phase == UpdatePhase.failed) {
      return;
    }
    _fail(updateFailureFromError(error));
  }

  void _onDone() {
    if (_ignoreEvents || _phase != UpdatePhase.running) return;
    _fail(updateStreamInterruptedFailure);
  }

  void _replaceItem(
    String dllId,
    UpdateRunItem Function(UpdateRunItem item) change,
  ) {
    final index = _items.indexWhere((item) => item.dllId == dllId);
    if (index == -1) {
      _items = [
        ..._items,
        change(UpdateRunItem.pending(dllId: dllId, filename: '')),
      ];
      return;
    }
    final items = [..._items];
    items[index] = change(items[index]);
    _items = items;
  }

  void _fail(UpdateFailure failure) {
    _stopwatch.stop();
    _failure = failure;
    _phase = UpdatePhase.failed;
    _currentDllId = null;
    _currentIndex = 0;
    _ignoreEvents = true;
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    unawaited(subscription?.cancel());
    unawaited(_cancelSession(session));
    notifyListeners();
  }

  void _dismissState() {
    _failure = null;
    _summary = null;
    _items = const [];
    _total = 0;
    _currentDllId = null;
    _currentIndex = 0;
    _phase = UpdatePhase.idle;
    _ignoreEvents = false;
  }

  Future<void> _refreshGame() async {
    final game = _lastGame;
    if (game == null) return;
    final generation = _generation;
    try {
      final refreshed = await repository.getGame(game.id);
      if (generation != _generation || refreshed.id != game.id) return;
      onGameRefreshed(refreshed);
    } catch (_) {
      // Keep the last known versions; the next load or scan refreshes them.
    }
  }

  int _countBucket(UpdateItemBucket bucket) {
    var total = 0;
    for (final item in _items) {
      if (item.bucket == bucket) total += 1;
    }
    return total;
  }

  @override
  void dispose() {
    _ignoreEvents = true;
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    unawaited(subscription?.cancel());
    unawaited(session?.cancel());
    _stopwatch.stop();
    super.dispose();
  }
}
