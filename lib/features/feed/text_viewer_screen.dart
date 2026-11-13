import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
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
/// текст из `.docx`. Выделение и копирование, редактирование текстовых файлов
/// с сохранением изменений обратно на доску, «Сохранить» и «Поделиться»;
/// очень большие текстовые файлы показываются с начала.
class TextViewerScreen extends StatefulWidget {
  const TextViewerScreen({
    super.key,
    required this.feed,
    required this.post,
    this.onSaveContent,
  });

  final FeedController feed;
  final Post post;

  /// Пользовательский обработчик сохранения изменённого содержимого (например,
  /// для файла внутри папки). Если не задан, но доска не в режиме чтения,
  /// обновляется сам пост-файл [post] через [FeedController.updateFileContent].
  final Future<Attachment?> Function(Uint8List bytes)? onSaveContent;

  static Future<void> open(
    BuildContext context,
    FeedController feed,
    Post post, {
    Future<Attachment?> Function(Uint8List bytes)? onSaveContent,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TextViewerScreen(
        feed: feed,
        post: post,
        onSaveContent: onSaveContent,
      ),
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

  late Attachment _attachment = widget.post.attachment!;
  late Post _currentPost = widget.post;
  late Future<_Document> _document = _loadDocument(_attachment);

  /// Код и таблицы читать удобнее моноширинным шрифтом.
  late bool _monospace = _codeExtensions.contains(
    _attachment.fileName.split('.').last.toLowerCase(),
  );

  /// Markdown: показать исходный текст вместо оформленного.
  bool _source = false;

  bool _editing = false;
  bool _savingEdit = false;
  String _initialEditText = '';
  final TextEditingController _editController = TextEditingController();

  Future<_Document> _loadDocument(Attachment attachment) => widget.feed.previews
      .load(attachment)
      .then<_Document>(
        (bytes) => attachment.isDocx
            ? _WordDocument(parseDocx(bytes))
            : _TextDocument(decodeTextPreview(bytes)),
      );

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool _canEditDocument(_Document? doc) {
    if (widget.feed.isReadOnly) return false;
    if (_attachment.isDocx) return false;
    if (doc is! _TextDocument) return false;
    if (doc.preview.truncated) return false;
    return true;
  }

  void _startEditing(_TextDocument doc) {
    _initialEditText = doc.preview.text;
    _editController.text = _initialEditText;
    setState(() => _editing = true);
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_editing || _editController.text == _initialEditText) return true;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.discardChangesTitle),
        content: Text(l.discardChangesText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.discard),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _cancelEditing() async {
    if (!await _confirmDiscardIfNeeded()) return;
    if (!mounted) return;
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    if (_savingEdit) return;
    final newText = _editController.text;
    if (newText == _initialEditText) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _savingEdit = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final bytes = Uint8List.fromList(utf8.encode(newText));

    try {
      Attachment? updatedAttachment;
      if (widget.onSaveContent != null) {
        updatedAttachment = await widget.onSaveContent!(bytes);
      } else {
        final updatedPost = await widget.feed.updateFileContent(
          _currentPost,
          bytes,
        );
        if (updatedPost != null) {
          _currentPost = updatedPost;
          updatedAttachment = updatedPost.attachment;
        }
      }

      if (!mounted) return;
      if (updatedAttachment != null) {
        setState(() {
          _attachment = updatedAttachment!;
          _document = Future.value(
            _TextDocument(decodeTextPreview(bytes)),
          );
          _editing = false;
          _savingEdit = false;
        });
        messenger.showSnackBar(SnackBar(content: Text(l.saved)));
      } else {
        setState(() => _savingEdit = false);
        final err = widget.feed.error;
        if (err != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.describeError(err))),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEdit = false);
      messenger.showSnackBar(SnackBar(content: Text(l.describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final feed = widget.feed;
    final messenger = ScaffoldMessenger.of(context);

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cancelEditing();
      },
      child: FutureBuilder<_Document>(
        future: _document,
        builder: (context, snapshot) {
          final document = snapshot.data;
          final canEdit = _canEditDocument(document);

          return CenteredPageFrame(
            child: Scaffold(
              appBar: AppBar(
                leading: _editing
                    ? IconButton(
                        tooltip: l.cancel,
                        icon: const Icon(Icons.close),
                        onPressed: _savingEdit ? null : _cancelEditing,
                      )
                    : null,
                title: Text(
                  _attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: _editing
                    ? [
                        if (_savingEdit)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: l.save,
                            icon: const Icon(Icons.check),
                            onPressed: _saveEdit,
                          ),
                      ]
                    : [
                        if (canEdit && document is _TextDocument)
                          IconButton(
                            tooltip: l.editText,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _startEditing(document),
                          ),
                        if (feed.canOpenExternally)
                          IconButton(
                            tooltip: l.openWith,
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => feed.openExternally(_currentPost),
                          ),
                        if (feed.canShare)
                          IconButton(
                            tooltip: l.share,
                            icon: const Icon(Icons.share),
                            onPressed: () => feed.sharePost(_currentPost),
                          ),
                        IconButton(
                          tooltip: l.save,
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            if (await feed.saveAttachment(_currentPost)) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l.savedFile(_attachment.fileName),
                                  ),
                                ),
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
                                await Clipboard.setData(
                                  ClipboardData(text: text),
                                );
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l.copied)),
                                );
                            }
                          },
                          itemBuilder: (_) => [
                            if (!_attachment.isDocx &&
                                (!_attachment.isMarkdown || _source))
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
                            PopupMenuItem(
                              value: _MenuAction.copyAll,
                              child: Text(l.copyAll),
                            ),
                          ],
                        ),
                      ],
              ),
              body: Builder(
                builder: (context) {
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
                  if (document == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_editing) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _editController,
                        enabled: !_savingEdit,
                        autofocus: true,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: _monospace || _attachment.isMarkdown
                            ? const TextStyle(
                                fontFamily: 'monospace',
                                height: 1.4,
                              )
                            : const TextStyle(height: 1.4),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    );
                  }
                  return SelectionArea(child: _content(context, document));
                },
              ),
            ),
          );
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
