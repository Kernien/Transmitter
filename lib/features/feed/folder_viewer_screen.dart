import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'image_viewer_screen.dart';
import 'media_player_screen.dart';
import 'text_viewer_screen.dart';

/// Экран просмотра содержимого папки: проводник с поддержкой вложенных
/// папок, хлебными крошками, открытием файлов и скачиванием.
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
  String _currentSubdir = '';

  FolderAttachment get folder => widget.post.folder!;

  void _navigateUp() {
    if (_currentSubdir.isEmpty) return;
    final lastSlash = _currentSubdir.lastIndexOf('/');
    setState(() {
      _currentSubdir =
          lastSlash == -1 ? '' : _currentSubdir.substring(0, lastSlash);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final feed = widget.feed;
    final post = widget.post;
    final isSavingFolder = feed.isSaving(post);
    final transfer = feed.transferProgress(post);

    final prefix = _currentSubdir.isEmpty ? '' : '$_currentSubdir/';
    final subdirs = <String, ({int count, int size})>{};
    final directFiles = <FolderEntry>[];
    var currentFilesCount = 0;
    var currentTotalSize = 0;

    for (final entry in folder.files) {
      final norm = entry.relativePath.replaceAll('\\', '/');
      if (!norm.startsWith(prefix)) continue;
      currentFilesCount++;
      currentTotalSize += entry.size;

      final remainder = norm.substring(prefix.length);
      final slashIndex = remainder.indexOf('/');
      if (slashIndex != -1) {
        final subName = remainder.substring(0, slashIndex);
        final current = subdirs[subName] ?? (count: 0, size: 0);
        subdirs[subName] = (
          count: current.count + 1,
          size: current.size + entry.size,
        );
      } else {
        directFiles.add(entry);
      }
    }

    final sortedSubdirs = subdirs.keys.toList()..sort();
    directFiles.sort((a, b) => a.fileName.compareTo(b.fileName));
    final totalItems = sortedSubdirs.length + directFiles.length;

    return PopScope(
      canPop: _currentSubdir.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigateUp();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentSubdir.isNotEmpty) {
                _navigateUp();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentSubdir.isEmpty
                    ? folder.name
                    : _currentSubdir.split('/').last,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${l.folderFilesCount(currentFilesCount)} · ${l.fileSize(currentTotalSize)}',
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
        body: Column(
          children: [
            _buildBreadcrumbs(theme),
            Expanded(
              child: totalItems == 0
                  ? Center(
                      child: Text(
                        l.folderEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: totalItems,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index < sortedSubdirs.length) {
                          final subName = sortedSubdirs[index];
                          final subInfo = subdirs[subName]!;
                          final subPath = prefix + subName;
                          return ListTile(
                            leading: Icon(
                              Icons.folder,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              subName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${l.folderFilesCount(subInfo.count)} · ${l.fileSize(subInfo.size)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() => _currentSubdir = subPath),
                          );
                        }

                        final entry = directFiles[index - sortedSubdirs.length];
                        final isSaving = _savingEntries.contains(entry.id);
                        return ListTile(
                          leading: _fileIcon(entry, theme),
                          title: Text(
                            entry.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(l.fileSize(entry.size)),
                          trailing: isSaving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    if (_currentSubdir.isEmpty) return const SizedBox.shrink();

    final parts = _currentSubdir.split('/');
    final crumbs = <Widget>[
      InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => setState(() => _currentSubdir = ''),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                folder.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    var accumulated = '';
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      accumulated = accumulated.isEmpty ? part : '$accumulated/$part';
      final pathForCrumb = accumulated;
      final isLast = i == parts.length - 1;

      crumbs.add(
        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
      );
      crumbs.add(
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: isLast ? null : () => setState(() => _currentSubdir = pathForCrumb),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              part,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isLast
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
                fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: crumbs),
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
