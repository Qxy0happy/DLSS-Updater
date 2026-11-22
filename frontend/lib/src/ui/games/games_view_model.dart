import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/daemon_connection.dart';
import '../settings/settings_view_model.dart';
import 'games_repository.dart';
import 'models.dart';
import 'update_models.dart';
import 'update_run_controller.dart';

export 'update_run_controller.dart' show UpdatePhase;

/// Where the current scan stands.
enum ScanPhase { idle, scanning, cancelling, completed, failed }

/// Games state: Steam root, scan progress, the game list, the detail selection
/// and the delegated update run.
///
/// The view renders this state only; every daemon call goes through the
/// repository injected at the destination boundary. The update run owns its
/// own state machine in [UpdateRunController]; this class forwards the API the
/// view and the tests use.
class GamesViewModel extends ChangeNotifier {
  GamesViewModel({
    required this.repository,
    required this.settings,
    this.connection,
  }) {
    _updates = UpdateRunController(
      repository: repository,
      settings: settings,
      connection: connection,
      isBlocked: () => updateBlocked,
      onScanRequested: startScan,
      onGameRefreshed: _mergeRefreshedGame,
    )..addListener(_onUpdatesChanged);
    settings.addListener(_onSettingsChanged);
    connection?.addListener(_onConnectionChanged);
  }

  final GamesRepository repository;
  final SettingsViewModel settings;
  final DaemonConnection? connection;

  final Stopwatch _stopwatch = Stopwatch();
  final List<ScanWarningInfo> _warnings = [];
  final Set<String> _selectedDllIds = {};

  late final UpdateRunController _updates;

  List<GameSummary> _games = const [];
  ScanPhase _phase = ScanPhase.idle;
  ScanProgress? _progress;
  ScanSummary? _summary;
  GamesFailure? _failure;
  bool _loading = false;
  String? _selectedGameId;
  ScanSession? _session;
  StreamSubscription<ScanUpdate>? _subscription;
  bool _ignoreEvents = false;
  int _generation = 0;
  GamesRequestKind _lastRequest = GamesRequestKind.library;

  List<GameSummary> get games => _games;

  ScanPhase get phase => _phase;

  ScanProgress? get progress => _progress;

  ScanSummary? get summary => _summary;

  GamesFailure? get failure => _failure;

  List<ScanWarningInfo> get warnings => List.unmodifiable(_warnings);

  bool get loading => _loading;

  String? get steamRoot => settings.steamRoot;

  List<String> get customFolders => settings.customFolders;

  bool get heroicDetected => settings.heroicDetected;

  bool get lutrisDetected => settings.lutrisDetected;

  bool get heroicEnabled => settings.heroicEnabled;

  bool get lutrisEnabled => settings.lutrisEnabled;

  /// True when at least one source can be scanned.
  bool get sourcesConfigured =>
      (steamRoot != null && steamRoot!.isNotEmpty) ||
      customFolders.isNotEmpty ||
      heroicEnabled ||
      lutrisEnabled;

  String? get selectedGameId => _selectedGameId;

  Set<String> get selectedDllIds => Set.unmodifiable(_selectedDllIds);

  bool get scanning =>
      _phase == ScanPhase.scanning || _phase == ScanPhase.cancelling;

  bool get cancelling => _phase == ScanPhase.cancelling;

  UpdatePhase get updatePhase => _updates.phase;

  List<UpdateRunItem> get updateItems => _updates.items;

  Map<String, UpdateRunItem> get updateItemsByDllId => _updates.itemsByDllId;

  UpdateRunSummary? get updateSummary => _updates.summary;

  UpdateFailure? get updateFailure => _updates.failure;

  bool get updating => _updates.updating;

  bool get cancellingUpdate => _updates.cancelling;

  bool get daemonAvailable {
    final connection = this.connection;
    return connection == null ||
        connection.status == DaemonConnectionStatus.connected;
  }

  /// True when neither an update nor a scan nor a missing daemon blocks one.
  bool get updateBlocked => updating || scanning || !daemonAvailable;

  /// DLLs of the selected game whose rows are checked.
  List<GameDll> get selectedDlls {
    final game = selectedGame;
    if (game == null) return const [];
    return [
      for (final dll in game.dlls)
        if (_selectedDllIds.contains(dll.id)) dll,
    ];
  }

  bool get canUpdateSelection => !updateBlocked && selectedDlls.isNotEmpty;

  UpdateRunItem? get currentUpdateItem => _updates.currentItem;

  int get updateTotalCount => _updates.totalCount;

  int get updateCurrentIndex => _updates.currentIndex;

  int get updateDoneCount => _updates.doneCount;

  int get updateUpdatedCount => _updates.updatedCount;

  int get updateSkippedCount => _updates.skippedCount;

  int get updateFailedCount => _updates.failedCount;

  GameSummary? get selectedGame {
    final id = _selectedGameId;
    if (id == null) return null;
    for (final game in _games) {
      if (game.id == id) return game;
    }
    return null;
  }

  /// Loads the persisted library; used at startup and for a refresh retry.
  Future<void> load() async {
    if (scanning) return;
    _lastRequest = GamesRequestKind.library;
    _loading = true;
    notifyListeners();
    try {
      await settings.detectLaunchers();
      _games = await repository.listGames();
      _failure = null;
      _pruneSelection();
    } on GamesException catch (error) {
      _failure = error.failure;
    } catch (error) {
      _failure = failureFromError(error, request: GamesRequestKind.library);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Opens the native picker through the settings store and persists a root.
  Future<void> chooseSteamRoot() async {
    try {
      final selected = await settings.chooseSteamRoot();
      if (selected == null) return;
      _clearSourceFailure();
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Removes the Steam source without touching the custom folders.
  Future<void> clearSteamRoot() async {
    try {
      await settings.clearSteamRoot();
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Opens the picker for the source that most likely needs replacing.
  ///
  /// With only custom folders configured, the custom picker is the useful
  /// one; otherwise the Steam picker is the primary path. The toolbar always
  /// offers both.
  Future<void> chooseSource() async {
    final root = steamRoot;
    if (root == null || root.isEmpty) {
      await addCustomFolder();
      return;
    }
    await chooseSteamRoot();
  }

  /// Opens the picker for one game directory and appends it to the sources.
  Future<void> addCustomFolder() async {
    try {
      final selected = await settings.chooseCustomFolder();
      if (selected == null) return;
      _clearSourceFailure();
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Persists the Heroic source toggle.
  Future<void> setHeroicEnabled(bool enabled) async {
    try {
      await settings.setHeroicEnabled(enabled);
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Persists the Lutris source toggle.
  Future<void> setLutrisEnabled(bool enabled) async {
    try {
      await settings.setLutrisEnabled(enabled);
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Removes one custom game folder from the sources.
  Future<void> removeCustomFolder(String path) async {
    try {
      await settings.removeCustomFolder(path);
      notifyListeners();
    } catch (_) {
      _failure = settingsFailure;
      notifyListeners();
    }
  }

  /// Starts a scan of every configured source.
  Future<void> startScan() async {
    if (scanning || updating) return;
    if (!sourcesConfigured) {
      _fail(noSourcesFailure);
      return;
    }
    _lastRequest = GamesRequestKind.scan;
    _generation += 1;
    _resetScan();
    _phase = ScanPhase.scanning;
    _stopwatch
      ..reset()
      ..start();
    notifyListeners();
    try {
      final session = repository.startScan(
        steamRoot: settings.steamRoot,
        customFolders: settings.customFolders,
        scanHeroic: settings.heroicEnabled,
        scanLutris: settings.lutrisEnabled,
      );
      _session = session;
      _subscription = session.events.listen(
        _onScanUpdate,
        onError: _onScanError,
        onDone: _onScanDone,
      );
    } on GamesException catch (error) {
      _fail(error.failure);
    } catch (error) {
      _fail(failureFromError(error, request: GamesRequestKind.scan));
    }
  }

  /// Cancels the running scan without waiting for its remaining events.
  ///
  /// The partial game list stays visible; the summary is built from the last
  /// progress counters and the list is reconciled with the store afterwards.
  Future<void> cancelScan() async {
    if (_phase != ScanPhase.scanning) return;
    _phase = ScanPhase.cancelling;
    _ignoreEvents = true;
    notifyListeners();

    final progress = _progress;
    final session = _session;
    final subscription = _subscription;
    _session = null;
    _subscription = null;
    // Do not wait for the cancelled call to unwind: the partial list and the
    // local summary must show immediately, and late events are ignored.
    unawaited(subscription?.cancel());
    unawaited(_cancelSession(session));

    _stopwatch.stop();
    _summary = ScanSummary(
      gameCount: progress?.gamesFound ?? _games.length,
      dllCount: progress?.dllsFound ?? _countDlls(_games),
      cancelled: true,
      durationMs: _stopwatch.elapsedMilliseconds,
    );
    _phase = ScanPhase.completed;
    notifyListeners();
    await _reloadGames(keepPartialWhenEmpty: true, generation: _generation);
  }

  /// Re-runs what failed: picks a folder, reloads the list or restarts a scan.
  Future<void> retry() async {
    final failure = _failure;
    if (failure == null) return;
    switch (failure.retry) {
      case GamesRetryAction.chooseRoot:
        await chooseSteamRoot();
      case GamesRetryAction.chooseSource:
        await chooseSource();
      case GamesRetryAction.scan:
        await startScan();
      case GamesRetryAction.reload:
        await load();
      case GamesRetryAction.retryDaemon:
        await connection?.retry();
        if (_lastRequest == GamesRequestKind.scan) {
          await startScan();
        } else {
          await load();
        }
    }
  }

  /// Starts an update for the selected DLLs of the selected game.
  ///
  /// [dllIds] lets a row-level action update exactly one DLL; without it the
  /// checked rows are used, in the order the detail panel displays them.
  Future<void> startUpdate({Iterable<String>? dllIds}) async {
    if (updateBlocked) return;
    final game = selectedGame;
    if (game == null) return;
    final requested = (dllIds ?? _selectedDllIds).toSet();
    final targets = [
      for (final dll in game.dlls)
        if (requested.contains(dll.id)) dll,
    ];
    if (targets.isEmpty) return;
    await _updates.start(game, targets);
  }

  /// Cancels the current update without waiting for remaining server events.
  Future<void> cancelUpdate() => _updates.cancel();

  /// Re-runs what the update failure suggests; the Close button dismisses it.
  Future<void> retryUpdate() => _updates.retry();

  /// Removes the run-level error and returns the detail panel to idle.
  void dismissUpdateFailure() => _updates.dismissFailure();

  void selectGame(String gameId) {
    final next = _selectedGameId == gameId ? null : gameId;
    if (next != _selectedGameId) _selectedDllIds.clear();
    _selectedGameId = next;
    notifyListeners();
  }

  void clearSelectedGame() {
    if (_selectedGameId == null) return;
    _selectedGameId = null;
    _selectedDllIds.clear();
    notifyListeners();
  }

  /// Selection hook used by the update ticket; rows toggle ids here.
  void toggleDllSelection(String dllId) {
    if (!_selectedDllIds.remove(dllId)) {
      _selectedDllIds.add(dllId);
    }
    notifyListeners();
  }

  bool isDllSelected(String dllId) => _selectedDllIds.contains(dllId);

  Future<void> _cancelSession(ScanSession? session) async {
    try {
      await session?.cancel();
    } catch (_) {
      // The call is already being torn down; the local summary still applies.
    }
  }

  void _onScanUpdate(ScanUpdate update) {
    if (_ignoreEvents || _phase != ScanPhase.scanning) return;
    switch (update) {
      case ScanStartedUpdate():
        _progress = const ScanProgress();
      case ScanLibraryUpdate(:final progress):
        _progress = progress;
      case GameFoundUpdate(:final game):
        _mergeGame(game);
      case ScanFinishedUpdate(:final summary):
        _stopwatch.stop();
        _summary = summary;
        _phase = ScanPhase.completed;
        notifyListeners();
        unawaited(
          _reloadGames(keepPartialWhenEmpty: true, generation: _generation),
        );
        return;
      case ScanFailedUpdate(:final failure):
        _fail(failure);
        return;
      case ScanWarningUpdate(:final warning):
        _warnings.add(warning);
    }
    notifyListeners();
  }

  void _onScanError(Object error) {
    if (_ignoreEvents || _phase == ScanPhase.completed) return;
    _stopwatch.stop();
    if (_phase == ScanPhase.failed && _failure != null) return;
    _fail(failureFromError(error, request: GamesRequestKind.scan));
  }

  void _onScanDone() {
    if (_ignoreEvents || _phase == ScanPhase.completed) return;
    if (_phase == ScanPhase.failed) return;
    _stopwatch.stop();
    _fail(streamInterruptedFailure);
  }

  Future<void> _reloadGames({
    required bool keepPartialWhenEmpty,
    required int generation,
  }) async {
    try {
      final remote = await repository.listGames();
      if (generation != _generation) return;
      if (remote.isEmpty && keepPartialWhenEmpty && _games.isNotEmpty) return;
      _games = remote;
      _pruneSelection();
      notifyListeners();
    } catch (_) {
      // The stream results stay visible when the refresh fails.
    }
  }

  void _mergeGame(GameSummary game) {
    final index = _games.indexWhere((existing) => existing.id == game.id);
    if (index == -1) {
      _games = [..._games, game];
    } else {
      final updated = [..._games];
      updated[index] = game;
      _games = updated;
    }
  }

  /// Merges a game the update controller re-read after a run.
  void _mergeRefreshedGame(GameSummary game) {
    _mergeGame(game);
    _pruneSelection();
    notifyListeners();
  }

  void _clearSourceFailure() {
    final retry = _failure?.retry;
    if (retry == GamesRetryAction.chooseRoot ||
        retry == GamesRetryAction.chooseSource) {
      _failure = null;
    }
  }

  void _resetScan() {
    _summary = null;
    _failure = null;
    _progress = null;
    _warnings.clear();
    _selectedDllIds.clear();
    _ignoreEvents = false;
  }

  void _fail(GamesFailure failure) {
    _failure = failure;
    _phase = ScanPhase.failed;
    _stopwatch.stop();
    _session = null;
    _subscription = null;
    notifyListeners();
  }

  void _pruneSelection() {
    final gameIds = {for (final game in _games) game.id};
    if (_selectedGameId != null && !gameIds.contains(_selectedGameId)) {
      _selectedGameId = null;
    }
    final dllIds = {
      for (final game in _games)
        for (final dll in game.dlls) dll.id,
    };
    _selectedDllIds.removeWhere((id) => !dllIds.contains(id));
  }

  void _onSettingsChanged() {
    notifyListeners();
  }

  void _onConnectionChanged() {
    notifyListeners();
  }

  void _onUpdatesChanged() {
    notifyListeners();
  }

  static int _countDlls(List<GameSummary> games) {
    var total = 0;
    for (final game in games) {
      total += game.dlls.length;
    }
    return total;
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    connection?.removeListener(_onConnectionChanged);
    _updates
      ..removeListener(_onUpdatesChanged)
      ..dispose();
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
