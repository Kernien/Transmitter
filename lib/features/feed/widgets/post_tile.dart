import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n.dart';
import '../../../domain/post.dart';
import '../feed_controller.dart';

enum _PostAction { select, note, share, save, copy, delete }

/// Один пост в ленте. Нажатие открывает ссылку или сохраняет файл, долгое
/// нажатие выделяет пост (см. режим выделения в FeedController), остальные
/// действия — через кнопку ⋮.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});

  final Post post;

  List<_PostAction> _actions({required bool canShare}) => [
    _PostAction.select,
    _PostAction.note,
    if (canShare) _PostAction.share,
    if (post.attachment != null) _PostAction.save,
    if (post.text.isNotEmpty) _PostAction.copy,
    _PostAction.delete,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(post.createdAt.toLocal())
        .format(context);
    final date = MaterialLocalizations.of(context)
        .formatShortDate(post.createdAt.toLocal());
    final (selecting, selected) = context.select<FeedController, (bool, bool)>(
      (f) => (f.isSelecting, f.isSelected(post)),
    );
    void toggle() => context.read<FeedController>().toggleSelection(post);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selecting
            ? toggle
            : switch (post.kind) {
                PostKind.link => () => _openLink(post.text),
                PostKind.file => () => _perform(context, _PostAction.save),
                PostKind.text => null,
              },
        onLongPress: toggle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selecting)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Checkbox(value: selected, onChanged: (_) => toggle()),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(selecting ? 4 : 12, 12, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _content(theme),
                    ),
                    if (post.note case final note?) _NoteView(note: note),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '${post.senderDevice} · $date $time',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        if (!selecting)
                          PopupMenuButton<_PostAction>(
                            tooltip: context.l10n.actions,
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: theme.colorScheme.outline,
                            ),
                            onSelected: (action) => _perform(context, action),
                            itemBuilder: (_) => [
                              for (final action in _actions(
                                canShare: context
                                    .read<FeedController>()
                                    .canShare,
                              ))
                                PopupMenuItem(
                                  value: action,
                                  child: _ActionLabel(
                                    action,
                                    hasNote: post.note != null,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) => switch (post.kind) {
    PostKind.text => Text(post.text),
    PostKind.link => Row(
      children: [
        Icon(Icons.link, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            post.text,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
    PostKind.file => _FileContent(post: post),
  };

  Future<void> _openLink(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> _perform(BuildContext context, _PostAction action) async {
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    switch (action) {
      case _PostAction.select:
        feed.toggleSelection(post);
      case _PostAction.note:
        final text = await showDialog<String>(
          context: context,
          builder: (_) => _NoteDialog(initial: post.note?.text ?? ''),
        );
        if (text != null) await feed.setNote(post, text);
      case _PostAction.share:
        await feed.sharePost(post);
      case _PostAction.save:
        await _save(context, post);
      case _PostAction.copy:
        await Clipboard.setData(ClipboardData(text: post.text));
        messenger.showSnackBar(SnackBar(content: Text(l.copied)));
      case _PostAction.delete:
        if (await _confirmDelete(context)) await feed.delete(post);
    }
  }

  static Future<void> _save(BuildContext context, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (await context.read<FeedController>().saveAttachment(post)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.savedFile(post.attachment!.fileName))),
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          post.kind == PostKind.file
              ? context.l10n.deleteFileTitle
              : context.l10n.deleteItemTitle,
        ),
        content: Text(context.l10n.deleteItemText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.action, {required this.hasNote});

  final _PostAction action;
  final bool hasNote;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, text) = switch (action) {
      _PostAction.select => (Icons.check_box_outlined, l.actionSelect),
      _PostAction.note => (
        hasNote ? Icons.edit_note : Icons.add_comment_outlined,
        hasNote ? l.actionEditNote : l.actionAddNote,
      ),
      _PostAction.share => (Icons.share, l.share),
      _PostAction.save => (Icons.download, l.actionSaveFile),
      _PostAction.copy => (Icons.copy, l.actionCopyText),
      _PostAction.delete => (Icons.delete_outline, l.actionDeleteEverywhere),
    };
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text)],
    );
  }
}

/// Комментарий под записью.
class _NoteView extends StatelessWidget {
  const _NoteView({required this.note});

  final PostNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.comment_outlined,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: context.l10n.noteEditedBy(note.editorDevice),
                child: Text(note.text, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Добавление или изменение комментария. Возвращает новый текст
/// (пустой — удалить комментарий) или `null`, если пользователь отменил.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.noteTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: l.noteHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Файл в ленте: имя, размер, подпись и кнопка сохранения.
class _FileContent extends StatelessWidget {
  const _FileContent({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attachment = post.attachment;
    final saving = context.select<FeedController, bool>(
      (f) => f.isSaving(post),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment?.fileName ?? context.l10n.fileFallback,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (attachment != null)
                    Text(
                      context.l10n.fileSize(attachment.size),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: context.l10n.save,
                    icon: const Icon(Icons.download),
                    onPressed: () => PostTile._save(context, post),
                  ),
          ],
        ),
        if (post.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(post.text),
        ],
      ],
    );
  }
}
