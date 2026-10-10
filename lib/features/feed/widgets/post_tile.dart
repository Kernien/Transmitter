import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
        onTap: post.kind == PostKind.link ? () => _openLink(post.text) : null,
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
        PostKind.file => Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(post.attachment?.fileName ?? 'Файл')),
            ],
          ),
      };

  Future<void> _openLink(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> _showMenu(BuildContext context) async {
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: post.text));
        messenger.showSnackBar(const SnackBar(content: Text('Скопировано')));
      case 'delete':
        await feed.delete(post);
    }
  }
}
