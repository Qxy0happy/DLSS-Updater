import 'dart:async';

import 'package:flutter/foundation.dart';

import 'daemon_client.dart';

/// The four connection states shown in the app-level banner.
enum DaemonConnectionStatus { starting, connected, unavailable, reconnecting }

/// The connection surface the UI depends on. Implemented by [DaemonController]
/// and by test fakes.
abstract class DaemonConnection extends ChangeNotifier {
  DaemonConnectionStatus get status;

  /// The most recent error, kept for display after a failed start or retry.
  String? get lastError;

  String? get daemonVersion;

  String? get protoVersion;

  String get dataDir;

  String get dllSourceDir;

  /// Starts the daemon; no-op when it is already running.
  Future<void> start();

  /// Manual retry from the banner; resets the restart budget.
  Future<void> retry();

  /// Restarts the daemon with a different DLL source directory.
  Future<void> restartWithDllSource(String dllSourceDir);

  /// Graceful shutdown for app exit.
  Future<void> shutdown();
}

/// Bounded exponential backoff: 250 ms, 500 ms, 1 s, 2 s, then 4 s.
Duration defaultDaemonBackoff(int attempt) {
  const base = Duration(milliseconds: 250);
  const cap = Duration(seconds: 4);
  final millis = base.inMilliseconds * (1 << (attempt - 1).clamp(0, 8));
  return millis >= cap.inMilliseconds ? cap : Duration(milliseconds: millis);
}

/// Owns the connection state machine around a [DaemonClient].
///
/// Transient failures (UNAVAILABLE, UNKNOWN, a crashed process) are retried
/// with bounded backoff and a fresh process. Configuration and handshake
/// errors stop the loop and stay visible until the user retries.
class DaemonController extends DaemonConnection {
  DaemonController({
    required this.client,
    Duration Function(int attempt)? backoff,
    this.maxAttempts = 5,
  }) : _backoff = backoff ?? defaultDaemonBackoff {
    client.onUnexpectedExit = _handleUnexpectedExit;
  }

  final DaemonClient client;
  final Duration Function(int attempt) _backoff;
  final int maxAttempts;

  DaemonConnectionStatus _status = DaemonConnectionStatus.starting;
  String? _lastError;
  String? _daemonVersion;
  String? _protoVersion;
  int _attempt = 0;
  bool _started = false;
  bool _shuttingDown = false;
  bool _connecting = false;
  Timer? _reconnectTimer;

  @override
  DaemonConnectionStatus get status => _status;

  @override
  String? get lastError => _lastError;

  @override
  String? get daemonVersion => _daemonVersion;

  @override
  String? get protoVersion => _protoVersion;

  @override
  String get dataDir => client.config.dataDir;

  @override
  String get dllSourceDir => client.config.dllSourceDir;

  @override
  Future<void> start() async {
    if (_started || _shuttingDown) return;
    _started = true;
    await _connect(DaemonConnectionStatus.starting);
  }

  @override
  Future<void> retry() async {
    if (_shuttingDown) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    _lastError = null;
    await _connect(DaemonConnectionStatus.starting);
  }

  @override
  Future<void> restartWithDllSource(String dllSourceDir) async {
    if (_shuttingDown) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    _lastError = null;
    client.config = client.config.copyWith(dllSourceDir: dllSourceDir);
    await _connect(DaemonConnectionStatus.reconnecting);
  }

  @override
  Future<void> shutdown() async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await client.shutdown();
    } finally {
      _status = DaemonConnectionStatus.unavailable;
      notifyListeners();
    }
  }

  Future<void> _connect(DaemonConnectionStatus pending) async {
    _status = pending;
    _connecting = true;
    notifyListeners();
    try {
      final handshake = await client.start();
      _status = DaemonConnectionStatus.connected;
      _daemonVersion = handshake.appVersion;
      _protoVersion = handshake.protoVersion;
      _lastError = null;
      _attempt = 0;
      notifyListeners();
    } on DaemonConfigException catch (error) {
      _status = DaemonConnectionStatus.unavailable;
      _lastError = error.message;
      notifyListeners();
    } on DaemonStartException catch (error) {
      _lastError = error.message;
      if (!error.retryable) {
        _status = DaemonConnectionStatus.unavailable;
        notifyListeners();
        return;
      }
      _scheduleReconnect();
    } catch (error) {
      _lastError = error.toString();
      _status = DaemonConnectionStatus.unavailable;
      notifyListeners();
    } finally {
      _connecting = false;
    }
  }

  void _handleUnexpectedExit(int exitCode) {
    if (_shuttingDown || _connecting) return;
    _lastError = 'The daemon exited unexpectedly (exit code $exitCode).';
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_shuttingDown) return;
    if (_attempt >= maxAttempts) {
      _status = DaemonConnectionStatus.unavailable;
      _lastError =
          '${_lastError ?? 'The daemon is unavailable.'} '
          'Automatic restart stopped after $maxAttempts attempts.';
      notifyListeners();
      return;
    }
    _attempt += 1;
    _status = DaemonConnectionStatus.reconnecting;
    notifyListeners();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff(_attempt), () {
      _reconnectTimer = null;
      if (!_shuttingDown) {
        unawaited(_connect(DaemonConnectionStatus.reconnecting));
      }
    });
  }

  @override
  void dispose() {
    client.onUnexpectedExit = null;
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
