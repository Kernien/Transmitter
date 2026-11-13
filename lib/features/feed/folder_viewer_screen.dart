import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'image_viewer_screen.dart';
import 'media_player_screen.dart';
import 'text_viewer_screen.dart';

/// Экран просмотра содержимого папки: список файлов с путями, размерами,
/// возможностью открыть любой файл или скачать всю папку.
class FolderViewerScreen extends StatefulWidget {
  const FolderViewerScreen({
    super.key,
    required this.feed,
    required this.post,
  });

  final FeedController feed;
  final Post post;

  static Future<void> open(
    BuildContext context,
    FeedController feed,
    Post post,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FolderViewerScreen(feed: feed, post: post),
    ),
  );

  @override
  State<FolderViewerScreen> createState() => _FolderViewerScreenState();
}

class _FolderViewerScreenState extends State<FolderViewerScreen> {
  final Set<String> _savingEntries = {};

  FolderAttachment get folder => widget.post.folder!;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final feed = widget.feed;
    final post = widget.post;
    final isSavingFolder = feed.isSaving(post);
    final transfer = feed.transferProgress(post);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(folder.name, overflow: TextOverflow.ellipsis),
            Text(
              '${l.folderFilesCount(folder.fileCount)} · ${l.fileSize(folder.totalSize)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (isSavingFolder || transfer != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    value: transfer != null && transfer.fraction > 0
                        ? transfer.fraction
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: l.saveFolder,
              icon: const Icon(Icons.download),
              onPressed: () => _saveWholeFolder(context),
            ),
        ],
      ),
      body: folder.files.isEmpty
          ? Center(
              child: Text(
                l.folderEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          : ListView.separated(
              itemCount: folder.files.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = folder.files[index];
                final isSaving = _savingEntries.contains(entry.id);
                return ListTile(
                  leading: _fileIcon(entry, theme),
                  title: Text(
                    entry.relativePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l.fileSize(entry.size)),
                  trailing: isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: l.save,
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () => _saveEntry(context, entry),
                        ),
                  onTap: () => _openEntry(context, entry),
                );
              },
            ),
    );
  }

  Widget _fileIcon(FolderEntry entry, ThemeData theme) {
    final attachment = entry.toAttachment();
    final IconData iconData;
    if (attachment.isImage) {
      iconData = Icons.image_outlined;
    } else if (attachment.isReadable) {
      iconData = Icons.description_outlined;
    } else if (attachment.isVideo) {
      iconData = Icons.movie_outlined;
    } else if (attachment.isAudio) {
      iconData = Icons.audiotrack_outlined;
    } else {
      iconData = Icons.insert_drive_file_outlined;
    }
    return Icon(iconData, color: theme.colorScheme.primary);
  }

  Future<void> _openEntry(BuildContext context, FolderEntry entry) async {
    final attachment = entry.toAttachment();
    final syntheticPost = Post(
      id: entry.id,
      kind: PostKind.file,
      createdAt: widget.post.createdAt,
      senderDevice: widget.post.senderDevice,
      attachment: attachment,
    );

    if (attachment.isImage) {
      await ImageViewerScreen.open(context, widget.feed, syntheticPost);
    } else if (attachment.isReadable) {
      await TextViewerScreen.open(context, widget.feed, syntheticPost);
    } else if (attachment.isVideo || attachment.isAudio) {
      if (MediaPlayerScreen.isSupported) {
        MediaPlayerScreen.open(context, widget.feed, syntheticPost);
      } else if (widget.feed.canOpenExternally) {
        await widget.feed.openAttachmentExternally(attachment);
      } else {
        if (!context.mounted) return;
        await _saveEntry(context, entry);
      }
    } else if (widget.feed.canOpenExternally) {
      await widget.feed.openAttachmentExternally(attachment);
    } else {
      await _saveEntry(context, entry);
    }
  }

  Future<void> _saveEntry(BuildContext context, FolderEntry entry) async {
    setState(() => _savingEntries.add(entry.id));
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final saved = await widget.feed.saveFolderEntry(entry);
      if (saved && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.savedFile(entry.fileName))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingEntries.remove(entry.id));
      }
    }
  }

  Future<void> _saveWholeFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final saved = await widget.feed.saveFolder(widget.post);
    if (saved && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.savedFolder(folder.name))),
      );
    }
  }
}
