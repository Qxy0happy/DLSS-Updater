import 'package:material_ui/material_ui.dart';

import 'backups/backups_view.dart';
import 'connection_banner.dart';
import 'games/games_view.dart';
import 'settings/settings_view.dart';

/// The three top-level destinations of the application.
enum AppDestination { games, backups, settings }

/// Application shell: a NavigationRail plus the selected destination.
///
/// Views render only; no business calls live here.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialDestination = AppDestination.games});

  final AppDestination initialDestination;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination = widget.initialDestination;

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: Text('Games'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_backup_restore_outlined),
      selectedIcon: Icon(Icons.settings_backup_restore),
      label: Text('Backups'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final view = switch (_destination) {
      AppDestination.games => const GamesView(),
      AppDestination.backups => const BackupsView(),
      AppDestination.settings => const SettingsView(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('DLSS Updater')),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _destination.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) {
                    setState(() {
                      _destination = AppDestination.values[index];
                    });
                  },
                  destinations: _destinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: view),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
