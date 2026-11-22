import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_info.dart';
import '../../data/daemon_connection.dart';
import 'settings_view_model.dart';

/// Settings destination: the frontend-owned directories, the DLL source
/// picker, and the app/daemon/proto versions.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static const String changeSourceKey = 'change-dll-source';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final connection = context.watch<DaemonConnection>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Directories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Data directory'),
            subtitle: SelectableText(settings.dataDir),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('DLL source directory'),
            subtitle: SelectableText(settings.dllSourceDir),
            trailing: FilledButton.tonal(
              key: const Key(changeSourceKey),
              onPressed: settings.changingSource
                  ? null
                  : settings.chooseDllSource,
              child: settings.changingSource
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ),
        ),
        if (settings.error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Could not change the DLL source'),
              subtitle: Text(settings.error!),
            ),
          ),
        const SizedBox(height: 24),
        Text('Versions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text(appVersion),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Daemon version'),
            subtitle: Text(connection.daemonVersion ?? 'Not connected'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.api),
            title: const Text('Proto version'),
            subtitle: Text(connection.protoVersion ?? 'Not connected'),
          ),
        ),
      ],
    );
  }
}
