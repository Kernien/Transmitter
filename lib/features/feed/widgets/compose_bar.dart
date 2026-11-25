import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/l10n.dart';
import '../../vaults/vaults_controller.dart';
import '../feed_controller.dart';

/// Поле ввода и кнопка отправки внизу ленты.
class ComposeBar extends StatefulWidget {
  const ComposeBar({super.key});

  @override
  State<ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<ComposeBar> {
  final _text = TextEditingController();
  String? _activeTagPrefix;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final prefix = _findTagPrefix();
    if (prefix != _activeTagPrefix) {
      setState(() => _activeTagPrefix = prefix);
    }
  }

  String? _findTagPrefix() {
    final text = _text.text;
    final sel = _text.selection;
    final cursor = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
    if (cursor == 0) return null;

    final before = text.substring(0, cursor);
    final lastHash = before.lastIndexOf('#');
    if (lastHash < 0) return null;

    if (lastHash > 0) {
      final prevChar = before[lastHash - 1];
      if (!RegExp(r'[\s\n\r\t.,!?;:()\[\]{}]').hasMatch(prevChar)) {
        return null;
      }
    }

    final query = before.substring(lastHash + 1);
    if (RegExp(r'\s').hasMatch(query)) return null;

    return query;
  }

  void _insertTag(String tag) {
    final text = _text.text;
    final sel = _text.selection;
    final cursor = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
    final before = text.substring(0, cursor);
    final lastHash = before.lastIndexOf('#');
    if (lastHash < 0) return;

    final after = text.substring(cursor);
    final replacement = '#$tag ';
    final newText = before.substring(0, lastHash) + replacement + after;
    final newCursor = lastHash + replacement.length;

    _text.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  void _registerTagsFromText(String text) {
    if (text.isEmpty) return;
    final tags = <String>{};
    for (final match in RegExp(r'#([a-zA-Z0-9_\u0400-\u04FF]+)').allMatches(text)) {
      final tag = match.group(1);
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }
    if (tags.isNotEmpty && mounted) {
      context.read<VaultsController?>()?.registerTags(tags);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = context.select<FeedController, bool>((f) => f.isSending);
    final maxFileSize = context.select<FeedController, int>((f) => f.maxFileSize);
    final canAttachMedia = context.select<FeedController, bool>((f) => f.canAttachMedia);

    final vaults = context.watch<VaultsController?>();
    final feed = context.watch<FeedController>();
    final allKnown = <String>{
      ...vaults?.allTags ?? const <String>[],
      ...feed.allTags,
    };

    List<String> suggestions = const [];
    if (_activeTagPrefix != null) {
      final query = _activeTagPrefix!.toLowerCase();
      suggestions = allKnown
          .where((t) => t.toLowerCase().startsWith(query))
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    // Панель ввода — отдельная зона: тон светлее ленты.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty)
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final tag = suggestions[i];
                    return ActionChip(
                      label: Text('#$tag'),
                      onPressed: () => _insertTag(tag),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
              child: Row(
                children: [
                  if (canAttachMedia)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.attachMediaTooltipOf(maxFileSize),
                      onPressed: sending ? null : _attachMedia,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.attachFileTooltipOf(maxFileSize),
                    onPressed: sending ? null : _attach,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.attachFolderTooltipOf(maxFileSize),
                    onPressed: sending ? null : _attachFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: context.l10n.composeHint,
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: sending ? context.l10n.cancelUpload : context.l10n.send,
                    onPressed: sending
                        ? () => context.read<FeedController>().cancelActiveSend()
                        : _send,
                    icon: sending
                        ? const Icon(Icons.close)
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _registerTagsFromText(text);
    final ok = await context.read<FeedController>().sendText(text);
    if (ok) _text.clear();
  }

  /// Текст из поля ввода становится подписью к файлу.
  Future<void> _attach() async {
    _registerTagsFromText(_text.text);
    final ok = await context.read<FeedController>().attachFile(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }

  Future<void> _attachFolder() async {
    _registerTagsFromText(_text.text);
    final ok = await context.read<FeedController>().attachFolder(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }

  Future<void> _attachMedia() async {
    _registerTagsFromText(_text.text);
    final ok = await context.read<FeedController>().attachMedia(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }
}
