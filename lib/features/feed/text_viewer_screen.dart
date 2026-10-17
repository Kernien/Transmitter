import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n.dart';
import '../../core/utils/text_decoding.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';

/// Текстовый файл прямо в приложении: выделение и копирование, моноширинный
/// шрифт для кода и таблиц, сохранение и «Поделиться». Очень большие файлы
/// показываются с начала.
class TextViewerScreen extends StatefulWidget {
  const TextViewerScreen({super.key, required this.feed, required this.post});

  final FeedController feed;
  final Post post;

  static Future<void> open(
    BuildContext context,
    FeedController feed,
    Post post,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TextViewerScreen(feed: feed, post: post),
    ),
  );

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  static const _codeExtensions = {
    'csv', 'tsv', 'json', 'xml', 'log', 'ini', 'conf', 'cfg', 'yaml', 'yml', //
    'toml', 'html', 'htm', 'css', 'js', 'ts', 'dart', 'py', 'java', 'kt',
    'swift', 'c', 'h', 'cpp', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'sh',
    'bat', 'ps1', 'sql', 'svg',
  };

  late final Attachment _attachment = widget.post.attachment!;
  late final Future<TextPreview> _text = widget.feed.previews
      .load(_attachment)
      .then(decodeTextPreview);

  /// Код и таблицы читать удобнее моноширинным шрифтом.
  late bool _monospace = _codeExtensions.contains(
    _attachment.fileName.split('.').last.toLowerCase(),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final feed = widget.feed;
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_attachment.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.monospaceFont,
            isSelected: _monospace,
            icon: const Icon(Icons.code),
            onPressed: () => setState(() => _monospace = !_monospace),
          ),
          IconButton(
            tooltip: l.copyAll,
            icon: const Icon(Icons.copy_all),
            onPressed: () async {
              final preview = await _text;
              await Clipboard.setData(ClipboardData(text: preview.text));
              messenger.showSnackBar(SnackBar(content: Text(l.copied)));
            },
          ),
          if (feed.canShare)
            IconButton(
              tooltip: l.share,
              icon: const Icon(Icons.share),
              onPressed: () => feed.sharePost(widget.post),
            ),
          IconButton(
            tooltip: l.save,
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (await feed.saveAttachment(widget.post)) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l.savedFile(_attachment.fileName))),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _text,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.describeError(snapshot.error!)),
              ),
            );
          }
          final preview = snapshot.data;
          if (preview == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final theme = Theme.of(context);
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (preview.truncated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l.textTruncated(l.fileSize(_attachment.size)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                Text(
                  preview.text,
                  style: _monospace
                      ? const TextStyle(fontFamily: 'monospace', height: 1.4)
                      : const TextStyle(height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
