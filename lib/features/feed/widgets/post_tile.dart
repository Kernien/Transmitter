import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n.dart';
import '../../../domain/post.dart';
import '../attachment_previews.dart';
import '../feed_controller.dart';
import '../folder_viewer_screen.dart';
import '../image_viewer_screen.dart';
import '../media_player_screen.dart';
import '../text_viewer_screen.dart';

enum _PostAction {
  select,
  note,
  share,
  save,
  openFolder,
  openWith,
  copy,
  selectText,
  delete,
}

/// Один пост в ленте. Нажатие открывает ссылку или сохраняет файл, долгое
/// нажатие выделяет пост (см. режим выделения в FeedController), остальные
/// действия — через кнопку ⋮.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});

  final Post post;

  List<_PostAction> _actions({
    required bool canShare,
    required bool canOpen,
    required bool readOnly,
  }) => [
    _PostAction.select,
    if (!readOnly) _PostAction.note,
    if (canShare) _PostAction.share,
    if (post.attachment != null) _PostAction.save,
    if (post.attachment != null && canOpen) _PostAction.openWith,
    if (post.folder != null) ...[
      _PostAction.openFolder,
      _PostAction.save,
    ],
    if (post.text.isNotEmpty) _PostAction.copy,
    if (post.text.isNotEmpty || post.note != null) _PostAction.selectText,
    if (!readOnly) _PostAction.delete,
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

    final isPending = post.id.startsWith('pending_');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selecting
            ? toggle
            : isPending
            ? null
            : switch (post.kind) {
                PostKind.link => () => _openLink(post.text),
                // Фото открывается на весь экран, остальные файлы сохраняются.
                PostKind.file when post.attachment?.isImage ?? false =>
                  () => ImageViewerScreen.open(
                    context,
                    context.read<FeedController>(),
                    post,
                  ),
                // Текст, Markdown и .docx читаются прямо в приложении.
                PostKind.file when post.attachment?.isReadable ?? false =>
                  () => TextViewerScreen.open(
                    context,
                    context.read<FeedController>(),
                    post,
                  ),
                // Видео и музыка — встроенный плеер; где его нет (Linux) —
                // другое приложение.
                PostKind.file
                    when (post.attachment?.isVideo ?? false) ||
                        (post.attachment?.isAudio ?? false) =>
                  () => _play(context),
                PostKind.file => () => _perform(context, _PostAction.save),
                PostKind.folder => () => FolderViewerScreen.open(
                  context,
                  context.read<FeedController>(),
                  post,
                ),
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
                        if (!selecting && !isPending)
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
                                canOpen: context
                                    .read<FeedController>()
                                    .canOpenExternally,
                                readOnly: context
                                    .read<FeedController>()
                                    .isReadOnly,
                              ))
                                PopupMenuItem(
                                  value: action,
                                  child: _ActionLabel(
                                    action,
                                    hasNote: post.note != null,
                                    isFolder: post.folder != null,
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
    PostKind.folder => _FolderContent(post: post),
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
      case _PostAction.openFolder:
        await FolderViewerScreen.open(context, feed, post);
      case _PostAction.openWith:
        await feed.openExternally(post);
      case _PostAction.save:
        if (post.folder != null) {
          await _saveFolder(context, post);
        } else {
          await _save(context, post);
        }
      case _PostAction.selectText:
        await showDialog<void>(
          context: context,
          builder: (_) => _SelectTextDialog(post: post),
        );
      case _PostAction.copy:
        await Clipboard.setData(ClipboardData(text: post.text));
        messenger.showSnackBar(SnackBar(content: Text(l.copied)));
      case _PostAction.delete:
        if (await _confirmDelete(context)) await feed.delete(post);
    }
  }

  void _play(BuildContext context) {
    final feed = context.read<FeedController>();
    if (MediaPlayerScreen.isSupported) {
      MediaPlayerScreen.open(context, feed, post);
    } else if (feed.canOpenExternally) {
      feed.openExternally(post);
    } else {
      _save(context, post);
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

  static Future<void> _saveFolder(BuildContext context, Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final folder = post.folder;
    if (folder == null) return;
    if (await context.read<FeedController>().saveFolder(post)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.savedFolder(folder.name))),
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
              : post.kind == PostKind.folder
              ? context.l10n.deleteFolderTitle
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
  const _ActionLabel(
    this.action, {
    required this.hasNote,
    this.isFolder = false,
  });

  final _PostAction action;
  final bool hasNote;
  final bool isFolder;

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
      _PostAction.openFolder => (Icons.folder_open, l.openFolder),
      _PostAction.save => (
        Icons.download,
        isFolder ? l.saveFolder : l.actionSaveFile,
      ),
      _PostAction.openWith => (Icons.open_in_new, l.openWith),
      _PostAction.copy => (Icons.copy, l.actionCopyText),
      _PostAction.selectText => (Icons.text_fields, l.actionSelectText),
      _PostAction.delete => (Icons.delete_outline, l.actionDeleteEverywhere),
    };
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        // Длинные надписи (крупный шрифт, узкий экран) переносятся.
        Flexible(child: Text(text)),
      ],
    );
  }
}

/// Карточка прикреплённой папки: иконка, название, число файлов, общий размер
/// и превью структуры файлов.
class _FolderContent extends StatelessWidget {
  const _FolderContent({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folder = post.folder;
    final (saving, transfer) = context.select(
      (FeedController f) => (f.isSaving(post), f.transferProgress(post)),
    );

    Widget trailing;
    if (transfer != null) {
      trailing = Padding(
        key: const ValueKey('transfer'),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: transfer.fraction > 0 ? transfer.fraction : null,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${transfer.percent}%',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
            if (transfer.bytesPerSecond > 0)
              Text(
                context.l10n.transferSpeed(transfer.bytesPerSecond),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      );
    } else if (saving) {
      trailing = const Padding(
        key: ValueKey('saving'),
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      trailing = IconButton(
        key: const ValueKey('save'),
        tooltip: context.l10n.saveFolder,
        icon: const Icon(Icons.download),
        onPressed: () => PostTile._saveFolder(context, post),
      );
    }

    final fileCount = folder?.fileCount ?? 0;
    final totalSize = folder?.totalSize ?? 0;
    final filesPreview = folder?.files.take(3).toList() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder?.name ?? context.l10n.folderTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${context.l10n.folderFilesCount(fileCount)} · ${context.l10n.fileSize(totalSize)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 52,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: trailing,
                ),
              ),
            ),
          ],
        ),
        if (filesPreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final file in filesPreview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            file.relativePath,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.fileSize(file.size),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (fileCount > filesPreview.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '… +${fileCount - filesPreview.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (post.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(post.text),
        ],
      ],
    );
  }
}

/// Текст записи и комментарий, из которых можно выделить и скопировать
/// любой кусок. В самой ленте текст не выделяется: долгое нажатие там
/// выделяет запись целиком, а нажатие на ссылку открывает её.
class _SelectTextDialog extends StatelessWidget {
  const _SelectTextDialog({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final note = post.note;
    return AlertDialog(
      title: Text(l.actionSelectText),
      content: SingleChildScrollView(
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.text.isNotEmpty) Text(post.text),
              if (note != null) ...[
                if (post.text.isNotEmpty) const SizedBox(height: 16),
                Text(
                  l.noteTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(note.text),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.closeAction),
        ),
      ],
    );
  }
}

/// Комментарий под записью: текст и кем/когда изменён.
class _NoteView extends StatelessWidget {
  const _NoteView({required this.note});

  final PostNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final time = TimeOfDay.fromDateTime(note.editedAt.toLocal()).format(context);
    final date = MaterialLocalizations.of(context).formatShortDate(
      note.editedAt.toLocal(),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  l.noteTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(note.text, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              '${l.noteEditedBy(note.editorDevice)} · $date $time',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Превью фото в ленте. Небольшие фото загружаются сами, для больших —
/// кнопка «Показать фото», чтобы не тратить трафик без спроса. Если формат
/// не поддерживается, превью просто не показывается — остаётся строка файла.
class _ImagePreview extends StatefulWidget {
  const _ImagePreview({required this.post, required this.attachment});

  final Post post;
  final Attachment attachment;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  static const double _height = 220;
  late bool _requested = widget.attachment.size <= attachmentPreviewAutoLimit;
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment.id != oldWidget.attachment.id) {
      _failed = false;
      _requested = widget.attachment.size <= attachmentPreviewAutoLimit;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final feed = context.read<FeedController>();
    final attachment = widget.attachment;
    if (widget.post.id.startsWith('pending_') && feed.previews.peek(attachment) == null) {
      return const SizedBox.shrink();
    }
    if (!_requested && feed.previews.peek(attachment) == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.image_outlined),
          label: Text(
            context.l10n.showPhoto(context.l10n.fileSize(attachment.size)),
          ),
          onPressed: () => setState(() => _requested = true),
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FutureBuilder(
        future: feed.previews.load(attachment),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.hasError) return const SizedBox.shrink();
          if (bytes == null) {
            return const SizedBox(
              height: _height,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return GestureDetector(
            onTap: () => ImageViewerScreen.open(context, feed, widget.post),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _height),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  // Расшифровываем в размер превью, а не в полный — экономит
                  // память на больших фото.
                  cacheWidth: (width * pixelRatio).round().clamp(1, 1600),
                  errorBuilder: (_, _, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _failed = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );
        },
      ),
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
    final (saving, transfer) = context.select(
      (FeedController f) => (f.isSaving(post), f.transferProgress(post)),
    );

    Widget trailing;
    if (transfer != null) {
      trailing = Padding(
        key: const ValueKey('transfer'),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: transfer.fraction > 0 ? transfer.fraction : null,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${transfer.percent}%',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
            if (transfer.bytesPerSecond > 0)
              Text(
                context.l10n.transferSpeed(transfer.bytesPerSecond),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      );
    } else if (saving) {
      trailing = const Padding(
        key: ValueKey('saving'),
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      trailing = IconButton(
        key: const ValueKey('save'),
        tooltip: context.l10n.save,
        icon: const Icon(Icons.download),
        onPressed: () => PostTile._save(context, post),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment != null && attachment.isImage)
          _ImagePreview(post: post, attachment: attachment),
        Row(
          children: [
            Icon(
              attachment == null
                  ? Icons.insert_drive_file_outlined
                  : attachment.isImage
                  ? Icons.image_outlined
                  : attachment.isReadable
                  ? Icons.description_outlined
                  : attachment.isVideo
                  ? Icons.movie_outlined
                  : attachment.isAudio
                  ? Icons.audiotrack_outlined
                  : Icons.insert_drive_file_outlined,
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
            SizedBox(
              width: 52,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: trailing,
                ),
              ),
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
