import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../update_models.dart';
import 'update_keys.dart';

/// Side panel with one row per DLL of the selected game.
class GameDetailPanel extends StatelessWidget {
  const GameDetailPanel({
    super.key,
    required this.game,
    required this.selectedDllIds,
    required this.onToggleDll,
    required this.onClose,
    required this.updateItems,
    required this.selectionEnabled,
    required this.canUpdateSelection,
    required this.canUpdateAny,
    required this.updateRunning,
    required this.onStartUpdate,
    required this.onUpdateDll,
  });

  static const Key panelKey = Key('game-detail');
  static const String emptyDllsMessage =
      'No known technology DLLs in this game.';

  final GameSummary game;
  final Set<String> selectedDllIds;
  final ValueChanged<String> onToggleDll;
  final VoidCallback onClose;
  final Map<String, UpdateRunItem> updateItems;
  final bool selectionEnabled;
  final bool canUpdateSelection;
  final bool canUpdateAny;
  final bool updateRunning;
  final VoidCallback onStartUpdate;
  final ValueChanged<String> onUpdateDll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: panelKey,
      width: 440,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        game.installPath,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('game-detail-close'),
                  tooltip: 'Close game details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: game.dlls.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyDllsMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('game-detail-dlls'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: game.dlls.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dll = game.dlls[index];
                      return _DllRow(
                        dll: dll,
                        selected: selectedDllIds.contains(dll.id),
                        selectionEnabled: selectionEnabled,
                        updateItem: updateItems[dll.id],
                        canUpdate: canUpdateAny,
                        onToggle: () => onToggleDll(dll.id),
                        onUpdate: () => onUpdateDll(dll.id),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    updateRunning
                        ? 'Update in progress'
                        : selectedDllIds.isEmpty
                        ? 'Select at least one DLL to update.'
                        : '${selectedDllIds.length} selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: UpdateKeys.selected,
                  onPressed: canUpdateSelection ? onStartUpdate : null,
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(updateRunning ? 'Updating…' : 'Update selected'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DllRow extends StatelessWidget {
  const _DllRow({
    required this.dll,
    required this.selected,
    required this.selectionEnabled,
    required this.updateItem,
    required this.canUpdate,
    required this.onToggle,
    required this.onUpdate,
  });

  final GameDll dll;
  final bool selected;
  final bool selectionEnabled;
  final UpdateRunItem? updateItem;
  final bool canUpdate;
  final VoidCallback onToggle;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Select ${dll.filename}',
            checked: selected,
            child: Checkbox(
              key: Key('dll-select-${dll.id}'),
              value: selected,
              onChanged: selectionEnabled ? (_) => onToggle() : null,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(dll.typeLabel, style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dll.filename,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  dll.path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Fact(text: 'Current ${dll.currentVersion}'),
                    _Fact(
                      text: dll.hasSource
                          ? 'Source ${dll.sourceVersion}'
                          : 'No source file',
                    ),
                    _Fact(
                      text: dll.exists ? 'On disk' : 'Not on disk',
                      highlight: !dll.exists,
                    ),
                    if (dll.missingAt != null)
                      _Fact(
                        text:
                            'Missing since ${_formatDateTime(dll.missingAt!)}',
                        highlight: true,
                      ),
                    if (updateItem != null)
                      _Fact(
                        text: updateItem!.statusLabel,
                        highlight:
                            updateItem!.bucket == UpdateItemBucket.failed,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('dll-update-${dll.id}'),
            tooltip: 'Update ${dll.filename}',
            onPressed: canUpdate ? onUpdate : null,
            icon: const Icon(Icons.system_update_alt, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.text, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: highlight
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
