import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/daemon_connection.dart';

/// Application-wide connection banner.
///
/// Always visible so the user knows whether the sidecar is usable; the
/// unavailable state keeps the last error and offers a manual retry.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  static const String startingLabel = 'Starting the daemon…';
  static const String connectedLabel = 'Daemon connected';
  static const String unavailableLabel = 'Daemon unavailable';
  static const String reconnectingLabel = 'Reconnecting to the daemon…';

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<DaemonConnection>();
    final colors = Theme.of(context).colorScheme;
    final (
      IconData icon,
      String label,
      Color background,
      Color foreground,
    ) = switch (connection.status) {
      DaemonConnectionStatus.starting => (
        Icons.hourglass_top,
        startingLabel,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      DaemonConnectionStatus.connected => (
        Icons.check_circle_outline,
        connectedLabel,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      DaemonConnectionStatus.unavailable => (
        Icons.error_outline,
        unavailableLabel,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      DaemonConnectionStatus.reconnecting => (
        Icons.sync,
        reconnectingLabel,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
    };
    final error = connection.lastError;

    return Material(
      key: const Key('daemon-status-banner'),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foreground, semanticLabel: label),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: foreground),
                  ),
                  if (error != null)
                    Text(
                      error,
                      key: const Key('daemon-last-error'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: foreground),
                    ),
                ],
              ),
            ),
            if (connection.status == DaemonConnectionStatus.unavailable)
              TextButton(
                key: const Key('daemon-retry'),
                onPressed: connection.retry,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
