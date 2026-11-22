import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/daemon_api.dart';
import '../../data/daemon_connection.dart';
import '../settings/settings_view_model.dart';
import '../widgets/empty_state.dart';
import 'games_repository.dart';
import 'games_view_model.dart';
import 'models.dart';
import 'update_models.dart';
import 'widgets/game_detail_panel.dart';
import 'widgets/update_keys.dart';

/// Games destination: Steam folder, scan controls, game list and DLL detail.
///
/// It provides its own repository inside this subtree, reading the protocol
/// seam from the root provider tree; the view model owns all daemon calls and
/// this widget only renders and forwards interactions.
class GamesView extends StatelessWidget {
  const GamesView({super.key});

  static const String emptyTitle = 'No games scanned yet';
  static const String emptyMessage =
      'Choose your Steam folder and/or add game folders, then run a scan. '
      'Games that contain updatable DLLs will appear here.';
  static const String noResultsTitle = 'No games found';
  static const String noResultsMessage =
      'The scan finished without finding games with known technology DLLs. '
      'Check the selected folders and any warnings, then scan again.';

  static const Key chooseRootKey = Key('games-choose-root');
  static const Key clearRootKey = Key('games-clear-root');
  static const Key addCustomFolderKey = Key('games-add-custom-folder');
  static const Key scanKey = Key('games-scan');
  static const Key cancelKey = Key('games-cancel');
  static const Key errorKey = Key('games-error');
  static const Key retryKey = Key('games-retry');
  static const Key progressKey = Key('games-progress');
  static const Key summaryKey = Key('games-summary');
  static const Key warningsKey = Key('games-warnings');
  static const Key listKey = Key('games-list');

  /// Key of the remove button for one custom game folder.
  static Key removeCustomFolderKey(String path) =>
      Key('games-remove-custom:$path');

  @override
  Widget build(BuildContext context) {
    return Provider<GamesRepository>(
      create: (context) => GamesRepository(context.read<DaemonApi>()),
      child: ChangeNotifierProvider<GamesViewModel>(
        create: (context) => GamesViewModel(
          repository: context.read<GamesRepository>(),
          settings: context.read<SettingsViewModel>(),
          connection: context.read<DaemonConnection>(),
        )..load(),
        child: const _GamesBody(),
      ),
    );
  }
}

class _GamesBody extends StatefulWidget {
  const _GamesBody();

  @override
  State<_GamesBody> createState() => _GamesBodyState();
}

class _GamesBodyState extends State<_GamesBody> {
  UpdateRunSummary? _shownSummary;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GamesViewModel>();
    final selected = viewModel.selectedGame;
    final updateSummary = viewModel.updateSummary;
    if (updateSummary != null && !identical(updateSummary, _shownSummary)) {
      _shownSummary = updateSummary;
      final items = List<UpdateRunItem>.of(viewModel.updateItems);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) =>
              _UpdateSummaryDialog(summary: updateSummary, items: items),
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScanToolbar(viewModel: viewModel),
        if (viewModel.failure != null)
          _ErrorPanel(failure: viewModel.failure!, onRetry: viewModel.retry),
        if (viewModel.phase == ScanPhase.scanning ||
            viewModel.phase == ScanPhase.cancelling)
          _ScanProgressPanel(viewModel: viewModel),
        if (viewModel.summary != null)
          _ScanSummaryPanel(summary: viewModel.summary!),
        if (viewModel.warnings.isNotEmpty)
          _ScanWarningsPanel(warnings: viewModel.warnings),
        if (viewModel.updateFailure != null)
          _UpdateErrorPanel(
            failure: viewModel.updateFailure!,
            onRetry: viewModel.retryUpdate,
            onDismiss: viewModel.dismissUpdateFailure,
          ),
        if (viewModel.updatePhase == UpdatePhase.running ||
            viewModel.updatePhase == UpdatePhase.cancelling)
          _UpdateProgressPanel(viewModel: viewModel),
        if (updateSummary != null)
          _UpdateSummaryPanel(
            summary: updateSummary,
            onShowDetails: () => showDialog<void>(
              context: context,
              builder: (_) => _UpdateSummaryDialog(
                summary: updateSummary,
                items: List<UpdateRunItem>.of(viewModel.updateItems),
              ),
            ),
          ),
        if (viewModel.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: viewModel.games.isEmpty
              ? _EmptyGames(phase: viewModel.phase)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _GameList(viewModel: viewModel)),
                    if (selected != null)
                      GameDetailPanel(
                        game: selected,
                        selectedDllIds: viewModel.selectedDllIds,
                        onToggleDll: viewModel.toggleDllSelection,
                        onClose: viewModel.clearSelectedGame,
                        updateItems: viewModel.updateItemsByDllId,
                        selectionEnabled: !viewModel.updateBlocked,
                        canUpdateSelection: viewModel.canUpdateSelection,
                        canUpdateAny: !viewModel.updateBlocked,
                        updateRunning: viewModel.updating,
                        onStartUpdate: () => viewModel.startUpdate(),
                        onUpdateDll: (dllId) =>
                            viewModel.startUpdate(dllIds: [dllId]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _UpdateErrorPanel extends StatelessWidget {
  const _UpdateErrorPanel({
    required this.failure,
    required this.onRetry,
    required this.onDismiss,
  });

  final UpdateFailure failure;
  final Future<void> Function() onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: UpdateKeys.failure,
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (failure.detail != null)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 4),
                  child: Text(
                    failure.detail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: UpdateKeys.dismiss,
                    onPressed: onDismiss,
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: UpdateKeys.retry,
                    onPressed: onRetry,
                    child: Text(failure.retryLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateProgressPanel extends StatelessWidget {
  const _UpdateProgressPanel({required this.viewModel});

  final GamesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = viewModel.currentUpdateItem;
    final total = viewModel.updateTotalCount;
    final done = viewModel.updateDoneCount;
    final index = viewModel.updateCurrentIndex;
    final position = total == 0
        ? 'Preparing update…'
        : '${index > 0 ? index : done} of $total';
    final counts =
        '${viewModel.updateUpdatedCount} updated · '
        '${viewModel.updateSkippedCount} skipped · '
        '${viewModel.updateFailedCount} failed';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: UpdateKeys.progress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Updating DLLs',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(position, style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total > 0 ? (done / total).clamp(0.0, 1.0) : null,
              ),
              const SizedBox(height: 12),
              Text(
                current?.filename ?? 'Starting update…',
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                counts,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final item in viewModel.updateItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              _itemIcon(item),
                              size: 16,
                              color: _itemColor(theme, item),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.statusLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _itemColor(theme, item),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: UpdateKeys.cancel,
                  onPressed: viewModel.cancellingUpdate
                      ? null
                      : viewModel.cancelUpdate,
                  icon: viewModel.cancellingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop),
                  label: Text(
                    viewModel.cancellingUpdate
                        ? 'Cancelling…'
                        : 'Cancel update',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _itemIcon(UpdateRunItem item) {
    if (item.state == UpdateItemState.pending) return Icons.schedule;
    if (item.state == UpdateItemState.running) return Icons.sync;
    return switch (item.bucket) {
      UpdateItemBucket.updated => Icons.check_circle_outline,
      UpdateItemBucket.failed => Icons.error_outline,
      UpdateItemBucket.skipped => Icons.remove_circle_outline,
      null => Icons.check_circle_outline,
    };
  }

  static Color _itemColor(ThemeData theme, UpdateRunItem item) {
    return switch (item.bucket) {
      UpdateItemBucket.updated => theme.colorScheme.primary,
      UpdateItemBucket.failed => theme.colorScheme.error,
      UpdateItemBucket.skipped => theme.colorScheme.onSurfaceVariant,
      null => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _UpdateSummaryPanel extends StatelessWidget {
  const _UpdateSummaryPanel({
    required this.summary,
    required this.onShowDetails,
  });

  final UpdateRunSummary summary;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = summary.cancelled ? 'Update cancelled' : 'Update complete';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: UpdateKeys.summary,
        child: ListTile(
          leading: Icon(
            summary.cancelled ? Icons.stop_circle_outlined : Icons.check_circle,
            color: summary.cancelled
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary,
          ),
          title: Text(title),
          subtitle: Text(_updateSummaryLine(summary)),
          trailing: TextButton(
            key: UpdateKeys.summaryDetails,
            onPressed: onShowDetails,
            child: const Text('View details'),
          ),
        ),
      ),
    );
  }
}

class _UpdateSummaryDialog extends StatelessWidget {
  const _UpdateSummaryDialog({required this.summary, required this.items});

  final UpdateRunSummary summary;
  final List<UpdateRunItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = items.where((item) => item.isFinished).toList();
    return AlertDialog(
      key: UpdateKeys.dialog,
      title: Text(summary.cancelled ? 'Update cancelled' : 'Update complete'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _updateSummaryLine(summary),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Duration: '
                '${(summary.durationMs / 1000).toStringAsFixed(1)} s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary.cancelled
                    ? 'Remaining items were cancelled.'
                    : 'All selected DLLs were processed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                key: UpdateKeys.dialogItems,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Per-item results'),
                children: finished.isEmpty
                    ? const [
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('No items were processed.'),
                        ),
                      ]
                    : [
                        for (final item in finished)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.filename),
                            subtitle: Text(item.statusLabel),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: UpdateKeys.dialogClose,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

String _updateSummaryLine(UpdateRunSummary summary) {
  final counts =
      '${summary.succeeded} updated · '
      '${summary.skipped} skipped · '
      '${summary.failed} failed';
  if (summary.durationMs <= 0) return counts;
  final seconds = (summary.durationMs / 1000).toStringAsFixed(1);
  return '$counts · $seconds s';
}

class _ScanToolbar extends StatelessWidget {
  const _ScanToolbar({required this.viewModel});

  final GamesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = viewModel.steamRoot;
    final folders = viewModel.customFolders;
    final busy = viewModel.scanning;
    final updating = viewModel.updating;
    final locked = busy || updating;
    final summary = <String>[
      ?root,
      if (folders.isNotEmpty)
        folders.length == 1
            ? '1 custom folder'
            : '${folders.length} custom folders',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scan sources',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary.isEmpty ? 'No sources selected' : summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: summary.isEmpty
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: GamesView.chooseRootKey,
                    onPressed: locked ? null : viewModel.chooseSteamRoot,
                    icon: const Icon(Icons.folder_outlined, size: 18),
                    label: const Text('Steam'),
                  ),
                  if (root != null)
                    IconButton(
                      key: GamesView.clearRootKey,
                      tooltip: 'Clear Steam folder',
                      onPressed: locked ? null : viewModel.clearSteamRoot,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  TextButton.icon(
                    key: GamesView.addCustomFolderKey,
                    onPressed: locked ? null : viewModel.addCustomFolder,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add folder'),
                  ),
                  const SizedBox(width: 4),
                  if (busy)
                    FilledButton.tonalIcon(
                      key: GamesView.cancelKey,
                      onPressed: viewModel.cancelling
                          ? null
                          : viewModel.cancelScan,
                      icon: viewModel.cancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.stop),
                      label: Text(
                        viewModel.cancelling ? 'Cancelling…' : 'Cancel',
                      ),
                    )
                  else
                    FilledButton.icon(
                      key: GamesView.scanKey,
                      onPressed: !viewModel.sourcesConfigured || updating
                          ? null
                          : viewModel.startScan,
                      icon: const Icon(Icons.search),
                      label: const Text('Scan'),
                    ),
                ],
              ),
              if (folders.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: folders.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = folders[index];
                      return Container(
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gamepad_outlined, size: 16),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Tooltip(
                                message: path,
                                child: Text(
                                  path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ),
                            IconButton(
                              key: GamesView.removeCustomFolderKey(path),
                              tooltip: 'Remove folder',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: locked
                                  ? null
                                  : () => viewModel.removeCustomFolder(path),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.failure, required this.onRetry});

  final GamesFailure failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: GamesView.errorKey,
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (failure.detail != null)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 4),
                  child: Text(
                    failure.detail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: GamesView.retryKey,
                  onPressed: onRetry,
                  child: Text(failure.retryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanProgressPanel extends StatelessWidget {
  const _ScanProgressPanel({required this.viewModel});

  final GamesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = viewModel.progress;
    final sourceLabel = progress != null && progress.sourceCount > 0
        ? 'Source ${progress.sourceIndex} of ${progress.sourceCount}'
        : 'Preparing scan…';
    final currentGame = progress?.currentGame ?? '';
    final counters = progress == null
        ? 'Reading the selected sources…'
        : '${_gamesLabel(progress.gamesFound)} · '
              '${_dllsLabel(progress.dllsFound)} found';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: GamesView.progressKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scanning sources',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(sourceLabel, style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 12),
              Text(
                currentGame.isEmpty
                    ? 'Reading the selected sources…'
                    : 'Checking $currentGame',
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                counters,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanWarningsPanel extends StatelessWidget {
  const _ScanWarningsPanel({required this.warnings});

  final List<ScanWarningInfo> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: GamesView.warningsKey,
        child: ExpansionTile(
          leading: Icon(
            Icons.warning_amber_outlined,
            color: theme.colorScheme.tertiary,
          ),
          title: Text(
            warnings.length == 1
                ? '1 scan warning'
                : '${warnings.length} scan warnings',
          ),
          subtitle: const Text('Review these paths; the scan continued.'),
          children: [
            for (final warning in warnings)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_off_outlined, size: 18),
                title: SelectableText(warning.path),
                subtitle: Text(warning.message),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanSummaryPanel extends StatelessWidget {
  const _ScanSummaryPanel({required this.summary});

  final ScanSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = summary.cancelled ? 'Scan cancelled' : 'Scan complete';
    final counts =
        '${_gamesLabel(summary.gameCount)} · ${_dllsLabel(summary.dllCount)}'
        '${summary.cancelled ? ' kept' : ''}';
    final seconds = (summary.durationMs / 1000).toStringAsFixed(1);
    final detail = summary.durationMs > 0 ? '$counts · $seconds s' : counts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        key: GamesView.summaryKey,
        child: ListTile(
          leading: Icon(
            summary.cancelled ? Icons.stop_circle_outlined : Icons.check_circle,
            color: summary.cancelled
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary,
          ),
          title: Text(title),
          subtitle: Text(detail),
        ),
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({required this.viewModel});

  final GamesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: GamesView.listKey,
      padding: const EdgeInsets.all(8),
      itemCount: viewModel.games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final game = viewModel.games[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('game-${game.id}'),
            selected: game.id == viewModel.selectedGameId,
            leading: const Icon(Icons.sports_esports_outlined),
            title: Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              game.installPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(_dllsLabel(game.dllCount)),
            onTap: () => viewModel.selectGame(game.id),
          ),
        );
      },
    );
  }
}

class _EmptyGames extends StatelessWidget {
  const _EmptyGames({required this.phase});

  final ScanPhase phase;

  @override
  Widget build(BuildContext context) {
    if (phase == ScanPhase.completed) {
      return const EmptyState(
        icon: Icons.search_off,
        title: GamesView.noResultsTitle,
        message: GamesView.noResultsMessage,
      );
    }
    return const EmptyState(
      icon: Icons.sports_esports_outlined,
      title: GamesView.emptyTitle,
      message: GamesView.emptyMessage,
    );
  }
}

String _gamesLabel(int count) => count == 1 ? '1 game' : '$count games';

String _dllsLabel(int count) => count == 1 ? '1 DLL' : '$count DLLs';
