import 'dart:io';

/// Launcher configuration roots found at the standard locations.
class LauncherDetection {
  const LauncherDetection({this.heroicConfig, this.lutrisDatabase});

  final String? heroicConfig;
  final String? lutrisDatabase;

  bool get heroic => heroicConfig != null;
  bool get lutris => lutrisDatabase != null;
}

/// Finds launcher metadata without asking the sidecar; the frontend uses this
/// only to pick the default toggle state.
abstract class LauncherDetector {
  Future<LauncherDetection> detect();
}

/// Checks the native and Flatpak locations Heroic and Lutris use.
class FileSystemLauncherDetector implements LauncherDetector {
  const FileSystemLauncherDetector({
    this.home,
    this.xdgConfigHome,
    this.xdgDataHome,
  });

  /// Overrides for tests; production leaves them null and reads the process
  /// environment.
  final String? home;
  final String? xdgConfigHome;
  final String? xdgDataHome;

  @override
  Future<LauncherDetection> detect() async {
    final home = this.home ?? Platform.environment['HOME'];
    final xdgConfig = xdgConfigHome ?? Platform.environment['XDG_CONFIG_HOME'];
    final xdgData = xdgDataHome ?? Platform.environment['XDG_DATA_HOME'];

    String? heroic;
    final heroicCandidates = <String>[
      if (xdgConfig != null && xdgConfig.isNotEmpty) '$xdgConfig/heroic',
      if (home != null && home.isNotEmpty) ...[
        '$home/.config/heroic',
        '$home/.var/app/com.heroicgameslauncher.hgl/config/heroic',
      ],
    ];
    for (final path in heroicCandidates) {
      if (await Directory(path).exists()) {
        heroic = path;
        break;
      }
    }

    String? lutris;
    final lutrisCandidates = <String>[
      if (xdgData != null && xdgData.isNotEmpty) '$xdgData/lutris/pga.db',
      if (home != null && home.isNotEmpty) ...[
        '$home/.local/share/lutris/pga.db',
        '$home/.var/app/net.lutris.Lutris/data/lutris/pga.db',
      ],
    ];
    for (final path in lutrisCandidates) {
      if (await File(path).exists()) {
        lutris = path;
        break;
      }
    }
    return LauncherDetection(heroicConfig: heroic, lutrisDatabase: lutris);
  }
}

/// Detector used by tests and by code paths that must not touch the filesystem.
class NoLauncherDetector implements LauncherDetector {
  const NoLauncherDetector();

  @override
  Future<LauncherDetection> detect() async => const LauncherDetection();
}
