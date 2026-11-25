import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../core/vault/vault_key.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final unselectedAvailable = widget.availableTags
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
                      InputChip(
                        label: Text('#$tag'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeTag(tag),
                        deleteIconColor: colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
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
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text('#$tag'),
                        onPressed: () => _toggleAvailableTag(tag),
                        visualDensity: VisualDensity.compact,
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
