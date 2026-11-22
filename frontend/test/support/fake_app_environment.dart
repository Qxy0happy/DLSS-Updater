import 'dart:io';

import 'package:dlss_updater/src/app_environment.dart';
import 'package:dlss_updater/src/app_exit.dart';
import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/data/directory_picker.dart';
import 'package:dlss_updater/src/data/launcher_detection.dart';
import 'package:dlss_updater/src/data/ui_settings.dart';
import 'package:dlss_updater/src/ui/settings/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_daemon_api.dart';

/// In-memory daemon connection for root-provider widget tests.
class FakeDaemonConnection extends DaemonConnection {
  FakeDaemonConnection({
    DaemonConnectionStatus initialStatus = DaemonConnectionStatus.connected,
    String? initialError,
    this.daemonVersionValue = '1.2.3',
    this.protoVersionValue = 'dlss.v1',
    this.dataDirValue = '/tmp/dlss-data',
    this.dllSourceDirValue = '/tmp/dlss-source',
  }) : _status = initialStatus,
       _lastError = initialError;

  DaemonConnectionStatus _status;
  String? _lastError;

  final String daemonVersionValue;
  final String protoVersionValue;
  final String dataDirValue;
  String dllSourceDirValue;

  int retryCalls = 0;
  int shutdownCalls = 0;
  final List<String> restartSources = <String>[];

  @override
  DaemonConnectionStatus get status => _status;

  @override
  String? get lastError => _lastError;

  @override
  String? get daemonVersion => daemonVersionValue;

  @override
  String? get protoVersion => protoVersionValue;

  @override
  String get dataDir => dataDirValue;

  @override
  String get dllSourceDir => dllSourceDirValue;

  /// Drives the banner from a test.
  void setStatus(DaemonConnectionStatus status, {String? error}) {
    _status = status;
    _lastError = error;
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> retry() async {
    retryCalls += 1;
  }

  @override
  Future<void> restartWithDllSource(String dllSourceDir) async {
    restartSources.add(dllSourceDir);
    dllSourceDirValue = dllSourceDir;
    notifyListeners();
  }

  @override
  Future<void> shutdown() async {
    shutdownCalls += 1;
  }
}

/// Programmable launcher detection.
class FakeLauncherDetector implements LauncherDetector {
  FakeLauncherDetector({this.detection = const LauncherDetection()});

  LauncherDetection detection;
  int calls = 0;

  @override
  Future<LauncherDetection> detect() async {
    calls += 1;
    return detection;
  }
}

/// Programmable directory picker.
class FakeDirectoryPicker implements DirectoryPicker {
  final List<String> queuedPaths = <String>[];
  final List<String?> initialDirectories = <String?>[];
  int calls = 0;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    calls += 1;
    initialDirectories.add(initialDirectory);
    if (queuedPaths.isEmpty) return null;
    return queuedPaths.removeAt(0);
  }
}

/// Builds a root environment with fakes, a temporary data directory and a real
/// settings view model.
AppEnvironment fakeAppEnvironment({
  FakeDaemonConnection? connection,
  FakeDirectoryPicker? picker,
  FakeLauncherDetector? detector,
  UiSettings initial = const UiSettings(),
  String? dataDir,
}) {
  String directory;
  if (dataDir != null) {
    directory = dataDir;
  } else {
    final created = Directory.systemTemp.createTempSync('dlss-ui-test-');
    directory = created.path;
    addTearDown(() {
      if (created.existsSync()) created.deleteSync(recursive: true);
    });
  }
  final conn = connection ?? FakeDaemonConnection();
  final settings = SettingsViewModel(
    store: UiSettingsStore(File('$directory/ui.json')),
    picker: picker ?? FakeDirectoryPicker(),
    connection: conn,
    dataDir: directory,
    detector: detector ?? FakeLauncherDetector(),
    initial: initial.copyWith(
      dllSourceDir: initial.dllSourceDir ?? conn.dllSourceDir,
    ),
  );
  return AppEnvironment(
    api: FakeDaemonApi(),
    connection: conn,
    settings: settings,
    exitHandler: AppExitHandler(conn),
  );
}
