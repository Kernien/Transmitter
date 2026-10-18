import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n.dart';
import '../../core/utils/docx_text.dart';
import '../../core/utils/text_decoding.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';

/// Содержимое документа для показа.
sealed class _Document {
  /// Весь текст — для «Копировать всё».
  String get plainText;
}

class _TextDocument extends _Document {
  _TextDocument(this.preview);

  final TextPreview preview;

  @override
  String get plainText => preview.text;
}

class _WordDocument extends _Document {
  _WordDocument(this.paragraphs);

  final List<DocxParagraph> paragraphs;

  @override
  String get plainText => paragraphs.map((p) => p.text).join('\n');
}

enum _MenuAction { monospace, source, copyAll }

/// Документ прямо в приложении: простой текст, Markdown (с оформлением) или
/// текст из `.docx`. Выделение и копирование, «Сохранить» и «Поделиться»;
/// очень большие текстовые файлы показываются с начала.
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
  late final Future<_Document> _document = widget.feed.previews
      .load(_attachment)
      .then<_Document>(
        (bytes) => _attachment.isDocx
            ? _WordDocument(parseDocx(bytes))
            : _TextDocument(decodeTextPreview(bytes)),
      );

  /// Код и таблицы читать удобнее моноширинным шрифтом.
  late bool _monospace = _codeExtensions.contains(
    _attachment.fileName.split('.').last.toLowerCase(),
  );

  /// Markdown: показать исходный текст вместо оформленного.
  bool _source = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final feed = widget.feed;
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_attachment.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (feed.canOpenExternally)
            IconButton(
              tooltip: l.openWith,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => feed.openExternally(widget.post),
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
          PopupMenuButton<_MenuAction>(
            tooltip: l.actions,
            onSelected: (action) async {
              switch (action) {
                case _MenuAction.monospace:
                  setState(() => _monospace = !_monospace);
                case _MenuAction.source:
                  setState(() => _source = !_source);
                case _MenuAction.copyAll:
                  final text = (await _document).plainText;
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger.showSnackBar(SnackBar(content: Text(l.copied)));
              }
            },
            itemBuilder: (_) => [
              if (!_attachment.isDocx && (!_attachment.isMarkdown || _source))
                CheckedPopupMenuItem(
                  value: _MenuAction.monospace,
                  checked: _monospace,
                  child: Text(l.monospaceFont),
                ),
              if (_attachment.isMarkdown)
                CheckedPopupMenuItem(
                  value: _MenuAction.source,
                  checked: _source,
                  child: Text(l.markdownSource),
                ),
              PopupMenuItem(value: _MenuAction.copyAll, child: Text(l.copyAll)),
            ],
          ),
        ],
      ),
      body: FutureBuilder(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error!;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is FormatException
                      ? l.documentUnreadable
                      : l.describeError(error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final document = snapshot.data;
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SelectionArea(child: _content(context, document));
        },
      ),
    );
  }

  Widget _content(BuildContext context, _Document document) {
    final theme = Theme.of(context);
    return switch (document) {
      _WordDocument(:final paragraphs) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final paragraph in paragraphs) _wordParagraph(theme, paragraph),
        ],
      ),
      _TextDocument(:final preview) when _attachment.isMarkdown && !_source =>
        Markdown(
          data: preview.text,
          padding: const EdgeInsets.all(16),
          onTapLink: (_, href, _) {
            final uri = href == null ? null : Uri.tryParse(href);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      _TextDocument(:final preview) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (preview.truncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.l10n.textTruncated(
                  context.l10n.fileSize(_attachment.size),
                ),
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
    };
  }

  Widget _wordParagraph(ThemeData theme, DocxParagraph paragraph) {
    final base = switch (paragraph.headingLevel) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      3 || 4 || 5 || 6 => theme.textTheme.titleMedium,
      _ => theme.textTheme.bodyLarge,
    };
    final text = Text.rich(
      TextSpan(
        children: [
          for (final run in paragraph.runs)
            TextSpan(
              text: run.text,
              style: TextStyle(
                fontWeight: run.bold ? FontWeight.bold : null,
                fontStyle: run.italic ? FontStyle.italic : null,
              ),
            ),
        ],
      ),
      style: base?.copyWith(height: 1.4),
    );
    return Padding(
      padding: EdgeInsets.only(
        top: paragraph.headingLevel > 0 ? 12 : 0,
        bottom: 8,
      ),
      child: paragraph.listItem
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: base),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}
