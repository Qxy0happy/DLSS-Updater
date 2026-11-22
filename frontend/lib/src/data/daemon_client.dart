import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';

import 'daemon_api.dart';
import 'grpc_daemon_api.dart';

/// Contract version this frontend speaks. A daemon that reports anything else
/// is a configuration error, not a transient failure.
const String expectedProtoVersion = 'dlss.v1';

/// Starts `dlssd`. Injected so widget tests never create a real process.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Builds the single gRPC channel. Injected together with a fake API so tests
/// can replace both halves of the transport.
typedef ChannelFactory = ClientChannel Function(String socketPath);

/// Builds the API over a real channel.
typedef DaemonApiFactory = DaemonApi Function(ClientChannel channel);

/// The explicit paths and binary the sidecar runs with.
class DaemonClientConfig {
  const DaemonClientConfig({
    required this.dataDir,
    required this.socketPath,
    required this.dllSourceDir,
    required this.executable,
  });

  final String dataDir;
  final String socketPath;
  final String dllSourceDir;
  final String executable;

  DaemonClientConfig copyWith({
    String? dataDir,
    String? socketPath,
    String? dllSourceDir,
    String? executable,
  }) {
    return DaemonClientConfig(
      dataDir: dataDir ?? this.dataDir,
      socketPath: socketPath ?? this.socketPath,
      dllSourceDir: dllSourceDir ?? this.dllSourceDir,
      executable: executable ?? this.executable,
    );
  }

  /// The exact command line the sidecar expects.
  List<String> get arguments => <String>[
    '--data-dir',
    dataDir,
    '--socket',
    socketPath,
    '--dll-source-dir',
    dllSourceDir,
  ];
}

/// A configuration problem that must be shown to the user without entering an
/// automatic restart loop.
class DaemonConfigException implements Exception {
  DaemonConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A failed start or handshake. [retryable] is false for configuration and
/// contract errors.
class DaemonStartException implements Exception {
  DaemonStartException(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// What the startup handshake established about the running sidecar.
class DaemonHandshake {
  const DaemonHandshake({required this.appVersion, required this.protoVersion});

  final String appVersion;
  final String protoVersion;
}

/// Whether [error] represents a temporarily unavailable daemon.
///
/// `UNAVAILABLE` and `UNKNOWN` (HTTP/2 terminated) both mean "the sidecar is
/// not there right now"; `DEADLINE_EXCEEDED` covers a daemon still starting.
bool isDaemonUnavailable(Object error) {
  if (error is! GrpcError) return false;
  switch (error.code) {
    case StatusCode.unavailable:
    case StatusCode.unknown:
    case StatusCode.deadlineExceeded:
      return true;
    default:
      return false;
  }
}

/// Owns the sidecar process and the single gRPC channel to it.
///
/// The channel is created once so later repositories keep a stable
/// [DaemonApi] across daemon restarts; the sidecar reconnects to the same
/// socket path.
class DaemonClient {
  DaemonClient({
    required this.config,
    required this.processStarter,
    ChannelFactory? channelFactory,
    DaemonApi? api,
    DaemonApiFactory? apiFactory,
    this.handshakeTimeout = const Duration(seconds: 10),
    this.handshakePoll = const Duration(milliseconds: 100),
    this.exitGrace = const Duration(seconds: 2),
  }) {
    if (api != null) {
      _api = api;
    } else {
      if (channelFactory == null) {
        throw ArgumentError('channelFactory or api is required');
      }
      _channel = channelFactory(config.socketPath);
      _api = (apiFactory ?? GrpcDaemonApi.new)(_channel!);
    }
  }

  DaemonClientConfig config;
  final ProcessStarter processStarter;
  final Duration handshakeTimeout;
  final Duration handshakePoll;
  final Duration exitGrace;

  ClientChannel? _channel;
  late final DaemonApi _api;
  Process? _process;
  StreamSubscription<String>? _stderrSubscription;
  final List<String> _stderrTail = <String>[];
  bool _stopping = false;
  bool _closed = false;

  /// Called when the process exits without [shutdown] being requested.
  void Function(int exitCode)? onUnexpectedExit;

  DaemonApi get api => _api;

  /// Starts the sidecar and completes the handshake. A previous process, if
  /// any, is stopped first.
  Future<DaemonHandshake> start() async {
    if (_closed) {
      throw DaemonConfigException('The daemon client is closed.');
    }
    if (_process != null) {
      await _stopProcess();
    }
    _stopping = false;
    try {
      _process = await processStarter(config.executable, config.arguments);
    } on ProcessException catch (error) {
      throw DaemonConfigException(
        'Could not start ${config.executable}: ${error.message}',
      );
    } catch (error) {
      throw DaemonConfigException(
        'Could not start ${config.executable}: $error',
      );
    }
    final process = _process!;
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_recordStderr);
    unawaited(
      process.exitCode.then((code) {
        if (identical(_process, process)) {
          _process = null;
        }
        if (!_stopping && !_closed) {
          onUnexpectedExit?.call(code);
        }
      }),
    );
    try {
      return await _handshake();
    } catch (_) {
      // Never leave an unusable daemon behind after a failed handshake.
      await _stopProcess();
      rethrow;
    }
  }

  /// Stops the current process, then starts a new one with the current config.
  Future<DaemonHandshake> restart() async {
    await _stopProcess();
    return start();
  }

  /// Shuts the sidecar down, removes the socket and closes the channel.
  Future<void> shutdown() async {
    if (_closed) return;
    await _stopProcess();
    _closed = true;
    await _api.close();
  }

  Future<DaemonHandshake> _handshake() async {
    final deadline = DateTime.now().add(handshakeTimeout);
    Object? lastError;
    while (true) {
      if (_process == null) {
        throw DaemonStartException(
          'The daemon exited before the handshake completed.'
          '${_stderrSuffix()}',
        );
      }
      try {
        final status = await _api.getStatus(GetStatusRequest());
        if (status.protoVersion != expectedProtoVersion) {
          throw DaemonConfigException(
            'The daemon speaks proto ${status.protoVersion}; this app requires '
            '$expectedProtoVersion.',
          );
        }
        return DaemonHandshake(
          appVersion: status.appVersion,
          protoVersion: status.protoVersion,
        );
      } on DaemonConfigException {
        rethrow;
      } on GrpcError catch (error) {
        if (!isDaemonUnavailable(error)) {
          throw DaemonStartException(
            'The daemon handshake failed: ${error.message ?? error.code}',
            retryable: false,
          );
        }
        lastError = error;
      } catch (error) {
        lastError = error;
      }
      if (!DateTime.now().isBefore(deadline)) {
        throw DaemonStartException(
          'Timed out waiting for the daemon handshake.'
          ' Last error: $lastError',
        );
      }
      await Future<void>.delayed(handshakePoll);
    }
  }

  Future<void> _stopProcess() async {
    _stopping = true;
    try {
      try {
        await _api.shutdown(ShutdownRequest()).timeout(exitGrace);
      } catch (_) {
        // The daemon may already be gone; the signal path below still runs.
      }
      final process = _process;
      if (process != null) {
        if (!await _waitForExit(process, exitGrace)) {
          process.kill(ProcessSignal.sigterm);
          if (!await _waitForExit(process, exitGrace)) {
            process.kill(ProcessSignal.sigkill);
            await _waitForExit(process, exitGrace);
          }
        }
      }
      // Cancelling the output subscription must never delay shutdown; the
      // stream belongs to a process that is already exiting.
      unawaited(_stderrSubscription?.cancel());
      _stderrSubscription = null;
      _cleanupSocket();
      _process = null;
    } finally {
      _stopping = false;
    }
  }

  /// Waits for [process] to exit, returning false on timeout.
  Future<bool> _waitForExit(Process process, Duration timeout) async {
    final winner = await Future.any<Object>(<Future<Object>>[
      process.exitCode.then<Object>((_) => true),
      Future<Object>.delayed(timeout, () => false),
    ]);
    return winner == true;
  }

  /// Removes the socket only when the path is still a socket. A regular file
  /// that replaced the socket belongs to someone else.
  Future<void> _cleanupSocket() async {
    try {
      if (await FileSystemEntity.type(config.socketPath) ==
          FileSystemEntityType.unixDomainSock) {
        await File(config.socketPath).delete();
      }
    } on FileSystemException {
      // Best effort: the daemon normally removes its own socket.
    }
  }

  void _recordStderr(String line) {
    if (line.trim().isEmpty) return;
    _stderrTail.add(line);
    if (_stderrTail.length > 5) {
      _stderrTail.removeAt(0);
    }
  }

  String _stderrSuffix() =>
      _stderrTail.isEmpty ? '' : ' Recent output: ${_stderrTail.join(' | ')}';
}
