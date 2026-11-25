import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/context_menu_region.dart';
import '../../core/vault/vault_key.dart';
import '../feed/feed_controller.dart';
import 'vaults_controller.dart';

/// Диалог управления тегами базы или отдельного элемента.
class ManageTagsDialog extends StatefulWidget {
  const ManageTagsDialog({
    super.key,
    required this.initialTags,
    this.availableTags = const [],
    this.title,
  });

  final List<String> initialTags;
  final List<String> availableTags;
  final String? title;

  /// Показывает диалог подтверждения удаления тега и, при согласии,
  /// удаляет тег из [VaultsController] и [FeedController] (если они доступны в дереве).
  /// Возвращает `true`, если тег был удалён.
  static Future<bool> confirmAndDelete(BuildContext context, String tag) async {
    final l = context.l10n;
    final theme = Theme.of(context);
    final vaults = Provider.of<VaultsController?>(context, listen: false);
    final feed = Provider.of<FeedController?>(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTagTitle(tag)),
        content: Text(l.deleteTagConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.deleteTagAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    await vaults?.deleteTag(tag);
    await feed?.deleteTagGlobally(tag);

    messenger?.showSnackBar(
      SnackBar(content: Text(l.tagDeleted(tag))),
    );
    return true;
  }

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> initialTags,
    List<String> availableTags = const [],
    String? title,
  }) async {
    final vaults = Provider.of<VaultsController?>(context, listen: false);
    final globalTags = vaults?.allTags ?? const <String>[];
    final merged = <String>{
      ...availableTags,
      ...globalTags,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => ManageTagsDialog(
        initialTags: initialTags,
        availableTags: merged,
        title: title,
      ),
    );

    if (result != null && result.isNotEmpty) {
      vaults?.registerTags(result);
    }
    return result;
  }

  @override
  State<ManageTagsDialog> createState() => _ManageTagsDialogState();
}

class _ManageTagsDialogState extends State<ManageTagsDialog> {
  late final List<String> _tags = List.of(widget.initialTags);
  late final List<String> _availableTags = List.of(widget.availableTags);
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = VaultKey.normalizeTag(raw);
    if (tag == null) return;
    final exists = _tags.any((t) => t.toLowerCase() == tag.toLowerCase());
    if (!exists) {
      setState(() => _tags.add(tag));
    }
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() => _tags.removeWhere((t) => t.toLowerCase() == tag.toLowerCase()));
  }

  void _toggleAvailableTag(String tag) {
    final index = _tags.indexWhere((t) => t.toLowerCase() == tag.toLowerCase());
    if (index >= 0) {
      setState(() => _tags.removeAt(index));
    } else {
      setState(() => _tags.add(tag));
    }
  }

  Future<void> _deleteTagPermanently(String tag) async {
    final deleted = await ManageTagsDialog.confirmAndDelete(context, tag);
    if (deleted && mounted) {
      setState(() {
        _tags.removeWhere((t) => t.toLowerCase() == tag.toLowerCase());
        _availableTags.removeWhere((t) => t.toLowerCase() == tag.toLowerCase());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final unselectedAvailable = _availableTags
        .where((t) => !_tags.any((cur) => cur.toLowerCase() == t.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text(widget.title ?? l.manageTagsTitle),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        labelText: l.tagHint,
                        prefixText: '#',
                        isDense: true,
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => _addTag(_textController.text),
                    icon: const Icon(Icons.add),
                    tooltip: l.add,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in _tags)
                      ContextMenuRegion<String>(
                        onSelected: (action) {
                          if (action == 'remove') {
                            _removeTag(tag);
                          } else if (action == 'delete') {
                            _deleteTagPermanently(tag);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                const Icon(Icons.close, size: 20),
                                const SizedBox(width: 12),
                                Text(l.removeFromDevice),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                                const SizedBox(width: 12),
                                Text(
                                  l.deleteTagAction,
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: InputChip(
                          label: Text('#$tag'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag),
                          deleteIconColor: colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ] else ...[
                Text(
                  l.noTagsYet,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (unselectedAvailable.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l.existingTags,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in unselectedAvailable)
                      ContextMenuRegion<String>(
                        onSelected: (_) => _deleteTagPermanently(tag),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                                const SizedBox(width: 12),
                                Text(
                                  l.deleteTagAction,
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: RawChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text('#$tag'),
                          onPressed: () => _toggleAvailableTag(tag),
                          deleteIcon: const Icon(Icons.delete_outline, size: 16),
                          deleteButtonTooltipMessage: l.deleteTagAction,
                          onDeleted: () => _deleteTagPermanently(tag),
                          deleteIconColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final pending = _textController.text;
            final tag = VaultKey.normalizeTag(pending);
            if (tag != null &&
                !_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
              _tags.add(tag);
            }
            Navigator.of(context).pop(_tags);
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
