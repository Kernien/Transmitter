import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/format_size.dart';
import '../../../domain/post.dart';
import '../feed_controller.dart';

/// Один пост в ленте. Нажатие на ссылку открывает её, долгое нажатие
/// открывает меню (копировать, удалить).
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});

  final Post post;

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
          PostKind.file => () => _save(context, post),
          PostKind.text => null,
        },
        onLongPress: () => _showMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _content(theme),
              const SizedBox(height: 6),
              Text(
                '${post.senderDevice} · $date $time',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
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

  static Future<void> _save(BuildContext context, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await context.read<FeedController>().saveAttachment(post);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text('Сохранено: ${post.attachment!.fileName}')));
    }
  }

  Future<void> _showMenu(BuildContext context) async {
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.attachment != null)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Сохранить файл'),
                onTap: () => Navigator.pop(context, 'save'),
              ),
            if (post.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Копировать'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить для всех устройств'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'save':
        await _save(context, post);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: post.text));
        messenger.showSnackBar(const SnackBar(content: Text('Скопировано')));
      case 'delete':
        await feed.delete(post);
    }
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
