import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/format_size.dart';
import '../../../domain/post.dart';
import '../feed_controller.dart';

enum _PostAction { save, copy, delete }

/// Один пост в ленте. Нажатие открывает ссылку или сохраняет файл; действия
/// доступны через кнопку ⋮ и долгим нажатием.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});

  final Post post;

  List<_PostAction> get _actions => [
        if (post.attachment != null) _PostAction.save,
        if (post.text.isNotEmpty) _PostAction.copy,
        _PostAction.delete,
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(post.createdAt.toLocal()).format(context);
    final date = MaterialLocalizations.of(context).formatShortDate(post.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: switch (post.kind) {
          PostKind.link => () => _openLink(post.text),
          PostKind.file => () => _perform(context, _PostAction.save),
          PostKind.text => null,
        },
        onLongPress: () => _showActionSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _content(theme),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${post.senderDevice} · $date $time',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  PopupMenuButton<_PostAction>(
                    tooltip: 'Действия',
                    icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.outline),
                    onSelected: (action) => _perform(context, action),
                    itemBuilder: (_) => [
                      for (final action in _actions)
                        PopupMenuItem(value: action, child: _ActionLabel(action)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) => switch (post.kind) {
        PostKind.text => SelectableText(post.text),
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

  Future<void> _showActionSheet(BuildContext context) async {
    final action = await showModalBottomSheet<_PostAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in _actions)
              ListTile(
                title: _ActionLabel(action),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
    if (action != null && context.mounted) await _perform(context, action);
  }

  Future<void> _perform(BuildContext context, _PostAction action) async {
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _PostAction.save:
        await _save(context, post);
      case _PostAction.copy:
        await Clipboard.setData(ClipboardData(text: post.text));
        messenger.showSnackBar(const SnackBar(content: Text('Скопировано')));
      case _PostAction.delete:
        if (await _confirmDelete(context)) await feed.delete(post);
    }
  }

  static Future<void> _save(BuildContext context, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await context.read<FeedController>().saveAttachment(post)) {
      messenger.showSnackBar(SnackBar(content: Text('Сохранено: ${post.attachment!.fileName}')));
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.kind == PostKind.file ? 'Удалить файл?' : 'Удалить сообщение?'),
        content: const Text('Оно исчезнет из облака и со всех устройств.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.action);

  final _PostAction action;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (action) {
      _PostAction.save => (Icons.download, 'Сохранить файл'),
      _PostAction.copy => (Icons.copy, 'Копировать текст'),
      _PostAction.delete => (Icons.delete_outline, 'Удалить для всех устройств'),
    };
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text)],
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
    final saving = context.select<FeedController, bool>((f) => f.isSaving(post));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insert_drive_file_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attachment?.fileName ?? 'Файл', style: theme.textTheme.titleSmall),
                  if (attachment != null)
                    Text(formatFileSize(attachment.size), style: theme.textTheme.bodySmall),
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
                    tooltip: 'Сохранить',
                    icon: const Icon(Icons.download),
                    onPressed: () => PostTile._save(context, post),
                  ),
          ],
        ),
        if (post.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText(post.text),
        ],
      ],
    );
  }
}
