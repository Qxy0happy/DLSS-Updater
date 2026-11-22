import 'dart:async';
import 'dart:io';

/// A controllable stand-in for `dart:io`'s [Process] so widget and unit tests
/// never spawn the real sidecar.
class FakeDaemonProcess implements Process {
  FakeDaemonProcess({this.pid = 4242, this.exitOnSignal = true});

  @override
  final int pid;

  /// When true (the default), [kill] completes [exitCode] as a real SIGTERM
  /// would. Set to false to simulate a daemon that ignores a signal.
  bool exitOnSignal;

  final StreamController<List<int>> _stdin = StreamController<List<int>>();
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  IOSink? _stdinSink;

  final List<ProcessSignal> signals = <ProcessSignal>[];

  @override
  IOSink get stdin => _stdinSink ??= IOSink(_stdin.sink);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (exitOnSignal) {
      exit(-15);
    }
    return true;
  }

  /// Simulates the process exiting on its own.
  void exit(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
    if (!_stdout.isClosed) {
      _stdout.close();
    }
    if (!_stderr.isClosed) {
      _stderr.close();
    }
  }

  void writeStderr(String line) {
    _stderr.add('$line\n'.codeUnits);
  }
}

/// Records spawns and returns programmable fake processes.
class FakeProcessStarter {
  final List<List<String>> calls = <List<String>>[];
  final List<FakeDaemonProcess> processes = <FakeDaemonProcess>[];

  /// When set, starting the process throws it instead.
  Object? error;

  /// When set, every returned process has this flag.
  bool exitOnSignal = true;

  Future<Process> start(String executable, List<String> arguments) async {
    calls.add(<String>[executable, ...arguments]);
    final failure = error;
    if (failure != null) throw failure;
    final process = FakeDaemonProcess(exitOnSignal: exitOnSignal);
    processes.add(process);
    return process;
  }
}
