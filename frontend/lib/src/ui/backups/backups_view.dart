import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/daemon_api.dart';
import '../common/dll_catalog.dart';
import '../widgets/empty_state.dart';
import 'backups_repository.dart';
import 'backups_view_model.dart';
import 'models.dart';

/// Backups destination: active backups grouped by game, an orphaned section,
/// and restored history, with confirmed restore/delete actions.
///
/// This widget provides its own repository and view model from the root
/// [DaemonApi] so the destination can be mounted on its own in tests.
class BackupsView extends StatelessWidget {
  const BackupsView({super.key});

  static const String emptyTitle = 'No backups yet';
  static const String emptyMessage =
      'When you update a DLL, a .dlsss backup is created next to the original '
      'file. Restore or delete it from here.';

  static const Key loadingKey = Key('backups-loading');
  static const Key emptyKey = Key('backups-empty');
  static const Key loadErrorKey = Key('backups-load-error');
  static const Key retryKey = Key('backups-retry');
  static const Key refreshKey = Key('backups-refresh');
  static const Key historyToggleKey = Key('backups-history-toggle');
  static const Key activeSectionKey = Key('active-backups-section');
  static const Key orphanSectionKey = Key('orphaned-backups-section');
  static const Key historySectionKey = Key('restored-history-section');
  static const Key operationErrorKey = Key('backup-operation-error');
  static const Key confirmRestoreKey = Key('confirm-restore');
  static const Key cancelRestoreKey = Key('cancel-restore');
  static const Key confirmDeleteKey = Key('confirm-delete');
  static const Key cancelDeleteKey = Key('cancel-delete');

  static Key restoreButtonKey(String backupId) =>
      Key('backup-restore-$backupId');

  static Key deleteButtonKey(String backupId) => Key('backup-delete-$backupId');

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BackupsRepository>(
          create: (context) => BackupsRepository(context.read<DaemonApi>()),
        ),
        ChangeNotifierProvider<BackupsViewModel>(
          create: (context) {
            final viewModel = BackupsViewModel(
              context.read<BackupsRepository>(),
            );
            unawaited(viewModel.load());
            return viewModel;
          },
        ),
      ],
      child: const _BackupsBody(),
    );
  }
}

class _BackupsBody extends StatelessWidget {
  const _BackupsBody();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BackupsViewModel>();

    if (viewModel.loading && !viewModel.hasLoaded) {
      return const Center(
        key: BackupsView.loadingKey,
        child: CircularProgressIndicator(),
      );
    }

    final loadFailure = viewModel.loadFailure;
    if (loadFailure != null) {
      return _LoadErrorState(failure: loadFailure, viewModel: viewModel);
    }

    return Column(
      children: [
        _Toolbar(viewModel: viewModel),
        if (viewModel.operationFailure case final failure?)
          _OperationError(failure: failure, viewModel: viewModel),
        if (viewModel.lastResult case final result?)
          _ResultBanner(message: result),
        Expanded(
          child: viewModel.isEmpty
              ? const EmptyState(
                  key: BackupsView.emptyKey,
                  icon: Icons.settings_backup_restore_outlined,
                  title: BackupsView.emptyTitle,
                  message: BackupsView.emptyMessage,
                )
              : _BackupList(viewModel: viewModel),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.viewModel});

  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = viewModel.sections.activeCount;
    final blocked = viewModel.loading || viewModel.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text('Backups', style: theme.textTheme.titleLarge),
          Expanded(
            child: count == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      count == 1 ? '1 active backup' : '$count active backups',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
          TextButton.icon(
            key: BackupsView.historyToggleKey,
            onPressed: blocked ? null : viewModel.toggleHistory,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.history),
            label: Text(
              viewModel.includeHistory
                  ? 'Hide restored history'
                  : 'Show restored history',
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: BackupsView.refreshKey,
            tooltip: 'Refresh backups',
            onPressed: blocked ? null : viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.failure, required this.viewModel});

  final BackupFailure failure;
  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unavailable = failure.reason == BackupFailureReason.daemonUnavailable;
    return Center(
      key: BackupsView.loadErrorKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                unavailable ? 'Daemon unavailable' : 'Could not load backups',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                failure.userMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: BackupsView.retryKey,
                onPressed: viewModel.loading ? null : viewModel.retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationError extends StatelessWidget {
  const _OperationError({required this.failure, required this.viewModel});

  final BackupFailure failure;
  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final title = switch (viewModel.failedOperation) {
      BackupOperation.delete => 'Delete failed',
      _ => 'Restore failed',
    };
    return Card(
      key: BackupsView.operationErrorKey,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(title),
        subtitle: Text(failure.userMessage),
        trailing: IconButton(
          tooltip: 'Dismiss',
          onPressed: viewModel.dismissOperationFailure,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(message),
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({required this.viewModel});

  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sections = viewModel.sections;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (sections.active.isNotEmpty)
          Column(
            key: BackupsView.activeSectionKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeader(
                title: 'Active backups',
                hint: 'Restorable copies created before an update.',
              ),
              for (final group in sections.active)
                _GameGroup(group: group, viewModel: viewModel),
            ],
          ),
        if (sections.orphans.isNotEmpty)
          Column(
            key: BackupsView.orphanSectionKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const _SectionHeader(
                title: 'Orphaned backups',
                hint:
                    'The target DLL is no longer on disk. Restoring works when '
                    'the game is still installed at its original location.',
              ),
              for (final group in sections.orphans)
                _GameGroup(group: group, viewModel: viewModel),
            ],
          ),
        if (viewModel.includeHistory)
          Column(
            key: BackupsView.historySectionKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const _SectionHeader(
                title: 'Restored history',
                hint: 'Backups that were restored or replaced by a newer one.',
              ),
              for (final group in sections.history)
                _GameGroup(group: group, viewModel: viewModel),
            ],
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameGroup extends StatelessWidget {
  const _GameGroup({required this.group, required this.viewModel});

  final BackupGroup group;
  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final count = group.backups.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('backup-group-${group.gameId}'),
        initiallyExpanded: true,
        leading: const Icon(Icons.sports_esports_outlined),
        title: Text(group.gameName),
        subtitle: Text(count == 1 ? '1 backup' : '$count backups'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final entry in group.backups)
            _BackupRow(entry: entry, viewModel: viewModel),
        ],
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.entry, required this.viewModel});

  final BackupEntry entry;
  final BackupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = viewModel.busy;
    final busyHere = viewModel.busyBackupId == entry.id;

    return Card(
      key: Key('backup-row-${entry.id}'),
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.isOrphan
                      ? Icons.link_off
                      : Icons.settings_backup_restore_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.dllFilename,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.isOrphan) const _Indicator(label: 'Orphan'),
                if (entry.isRestored)
                  const _Indicator(label: 'Restored')
                else if (!entry.isActive)
                  const _Indicator(label: 'Inactive'),
                const SizedBox(width: 8),
                if (entry.isActive)
                  FilledButton.tonalIcon(
                    key: BackupsView.restoreButtonKey(entry.id),
                    onPressed: disabled
                        ? null
                        : () => _confirmRestore(context, entry),
                    icon: busyHere
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore, size: 18),
                    label: const Text('Restore'),
                  ),
                const SizedBox(width: 4),
                TextButton.icon(
                  key: BackupsView.deleteButtonKey(entry.id),
                  onPressed: disabled
                      ? null
                      : () => _confirmDelete(context, entry),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Field(label: 'Type', value: dllTypeLabel(entry.dllType)),
                _Field(
                  label: 'Original version',
                  value: entry.originalVersion.isEmpty
                      ? 'Unknown'
                      : entry.originalVersion,
                ),
                _Field(label: 'Size', value: formatBackupSize(entry.sizeBytes)),
                _Field(
                  label: 'Created',
                  value: formatBackupTimestamp(entry.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Tooltip(
                    message: entry.targetPath,
                    child: Text(
                      entry.targetPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: colors.onTertiaryContainer),
      ),
    );
  }
}

Future<void> _confirmRestore(BuildContext context, BackupEntry entry) async {
  final viewModel = context.read<BackupsViewModel>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Restore DLL backup?'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Game: ${entry.gameName}'),
              Text('DLL: ${entry.dllFilename}'),
              Text(
                'Backup version: '
                '${entry.originalVersion.isEmpty ? 'Unknown' : entry.originalVersion}',
              ),
              const SizedBox(height: 12),
              const Text(
                'This overwrites the current DLL with the backup version. A '
                'safety copy of the current file is created first.',
              ),
              if (entry.isOrphan) ...[
                const SizedBox(height: 8),
                const Text(
                  'This game is no longer in your library. It must still be '
                  'installed at its original location for the restore to '
                  'succeed.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: BackupsView.cancelRestoreKey,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: BackupsView.confirmRestoreKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await viewModel.restoreBackup(entry);
  }
}

Future<void> _confirmDelete(BuildContext context, BackupEntry entry) async {
  final viewModel = context.read<BackupsViewModel>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete backup?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Game: ${entry.gameName}'),
              Text('DLL: ${entry.dllFilename}'),
              const SizedBox(height: 12),
              const Text(
                'This permanently deletes the backup file. This cannot be '
                'undone.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: BackupsView.cancelDeleteKey,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: BackupsView.confirmDeleteKey,
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await viewModel.deleteBackup(entry);
  }
}
