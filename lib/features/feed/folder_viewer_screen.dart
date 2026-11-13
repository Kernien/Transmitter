import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'image_viewer_screen.dart';
import 'media_player_screen.dart';
import 'text_viewer_screen.dart';

enum _EntryMenuAction { save, edit, replace, rename, move, delete }

enum _SubdirMenuAction { rename, move, delete }

/// Экран просмотра и редактирования содержимого папки: проводник с поддержкой
/// вложенных папок, хлебными крошками, открытием файлов, скачиванием,
/// удалением, переименованием, перемещением и добавлением/заменой файлов.
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
  bool _busy = false;
  late Post _fallbackPost = widget.post;

  @override
  void initState() {
    super.initState();
    widget.feed.addListener(_onFeedChanged);
  }

  @override
  void dispose() {
    widget.feed.removeListener(_onFeedChanged);
    super.dispose();
  }

  void _onFeedChanged() {
    if (!mounted) return;
    final found = widget.feed.posts
        .where((p) => p.id == widget.post.id)
        .firstOrNull;
    if (found != null) {
      _fallbackPost = found;
    }
    setState(() {});
  }

  Post get _currentPost =>
      widget.feed.posts.where((p) => p.id == widget.post.id).firstOrNull ??
      _fallbackPost;

  FolderAttachment get folder => _currentPost.folder!;

  void _navigateUp() {
    if (_currentSubdir.isEmpty) return;
    final lastSlash = _currentSubdir.lastIndexOf('/');
    setState(() {
      _currentSubdir =
          lastSlash == -1 ? '' : _currentSubdir.substring(0, lastSlash);
    });
  }

  /// Все известные относительные пути подпапок внутри [folder].
  List<String> _allSubdirs() {
    final dirs = <String>{''};
    for (final entry in folder.files) {
      final norm = entry.relativePath.replaceAll('\\', '/');
      final parts = norm.split('/');
      var acc = '';
      for (var i = 0; i < parts.length - 1; i++) {
        acc = acc.isEmpty ? parts[i] : '$acc/${parts[i]}';
        dirs.add(acc);
      }
    }
    return dirs.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final feed = widget.feed;
    final post = _currentPost;
    final isReadOnly = feed.isReadOnly;
    final isSavingFolder = feed.isSaving(post);
    final transfer = feed.transferProgress(post);

    var prefix = _currentSubdir.isEmpty ? '' : '$_currentSubdir/';
    // Если после удаления/перемещения текущая подпапка опустела, поднимаемся
    // на уровень выше, где ещё есть файлы.
    while (_currentSubdir.isNotEmpty &&
        !folder.files.any(
          (e) => e.relativePath.replaceAll('\\', '/').startsWith(prefix),
        )) {
      final lastSlash = _currentSubdir.lastIndexOf('/');
      _currentSubdir =
          lastSlash == -1 ? '' : _currentSubdir.substring(0, lastSlash);
      prefix = _currentSubdir.isEmpty ? '' : '$_currentSubdir/';
    }

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
      child: CenteredPageFrame(
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
              if (!isReadOnly) ...[
                IconButton(
                  tooltip: l.addFilesToFolder,
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: _busy ? null : () => _addFilesToCurrentSubdir(context),
                ),
                if (_currentSubdir.isEmpty)
                  IconButton(
                    tooltip: l.rename,
                    icon: const Icon(Icons.drive_file_rename_outline),
                    onPressed: _busy ? null : () => _renameRootFolder(context),
                  ),
              ],
              if (_busy || isSavingFolder || transfer != null)
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${l.folderFilesCount(subInfo.count)} · ${l.fileSize(subInfo.size)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isReadOnly)
                                    PopupMenuButton<_SubdirMenuAction>(
                                      tooltip: l.actions,
                                      enabled: !_busy,
                                      onSelected: (action) => _onSubdirAction(
                                        context,
                                        action,
                                        subName: subName,
                                        subPath: subPath,
                                      ),
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: _SubdirMenuAction.rename,
                                          child: _menuRow(
                                            Icons.drive_file_rename_outline,
                                            l.rename,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: _SubdirMenuAction.move,
                                          child: _menuRow(
                                            Icons.drive_file_move_outlined,
                                            l.moveItem,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: _SubdirMenuAction.delete,
                                          child: _menuRow(
                                            Icons.delete_outline,
                                            l.delete,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () =>
                                  setState(() => _currentSubdir = subPath),
                            );
                          }

                          final entry =
                              directFiles[index - sortedSubdirs.length];
                          final isSaving = _savingEntries.contains(entry.id);
                          final attachment = entry.toAttachment();
                          final canEditText =
                              !isReadOnly &&
                              attachment.isText &&
                              !attachment.isDocx;

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
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l.save,
                                        icon: const Icon(
                                          Icons.download_outlined,
                                        ),
                                        onPressed: () =>
                                            _saveEntry(context, entry),
                                      ),
                                      if (!isReadOnly)
                                        PopupMenuButton<_EntryMenuAction>(
                                          tooltip: l.actions,
                                          enabled: !_busy,
                                          onSelected: (action) => _onEntryAction(
                                            context,
                                            action,
                                            entry,
                                          ),
                                          itemBuilder: (_) => [
                                            if (canEditText)
                                              PopupMenuItem(
                                                value: _EntryMenuAction.edit,
                                                child: _menuRow(
                                                  Icons.edit_outlined,
                                                  l.editText,
                                                ),
                                              ),
                                            PopupMenuItem(
                                              value: _EntryMenuAction.rename,
                                              child: _menuRow(
                                                Icons.drive_file_rename_outline,
                                                l.rename,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: _EntryMenuAction.move,
                                              child: _menuRow(
                                                Icons.drive_file_move_outlined,
                                                l.moveItem,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: _EntryMenuAction.replace,
                                              child: _menuRow(
                                                Icons.upload_file_outlined,
                                                l.replaceFile,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: _EntryMenuAction.save,
                                              child: _menuRow(
                                                Icons.download_outlined,
                                                l.actionSaveFile,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: _EntryMenuAction.delete,
                                              child: _menuRow(
                                                Icons.delete_outline,
                                                l.delete,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                            onTap: () => _openEntry(context, entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(text)),
    ],
  );

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onEntryAction(
    BuildContext context,
    _EntryMenuAction action,
    FolderEntry entry,
  ) async {
    switch (action) {
      case _EntryMenuAction.save:
        await _saveEntry(context, entry);
      case _EntryMenuAction.edit:
        await _openEntry(context, entry);
      case _EntryMenuAction.rename:
        await _renameEntry(context, entry);
      case _EntryMenuAction.move:
        await _moveEntry(context, entry);
      case _EntryMenuAction.replace:
        await _replaceEntry(context, entry);
      case _EntryMenuAction.delete:
        await _deleteEntry(context, entry);
    }
  }

  Future<void> _onSubdirAction(
    BuildContext context,
    _SubdirMenuAction action, {
    required String subName,
    required String subPath,
  }) async {
    switch (action) {
      case _SubdirMenuAction.rename:
        await _renameSubdir(context, subName: subName, subPath: subPath);
      case _SubdirMenuAction.move:
        await _moveSubdir(context, subName: subName, subPath: subPath);
      case _SubdirMenuAction.delete:
        await _deleteSubdir(context, subPath: subPath);
    }
  }

  Future<void> _renameRootFolder(BuildContext context) async {
    final newName = await _promptName(context, initial: folder.name);
    if (newName == null || newName == folder.name || !mounted) return;
    await _runBusy(() async {
      final updatedFolder = FolderAttachment(
        name: newName,
        files: folder.files,
      );
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        updatedFolder,
      );
      if (updated != null) _fallbackPost = updated;
    });
  }

  Future<void> _renameEntry(BuildContext context, FolderEntry entry) async {
    final newName = await _promptName(context, initial: entry.fileName);
    if (newName == null || newName == entry.fileName || !mounted) return;
    final cleanName = newName.replaceAll(RegExp(r'[/\\]'), '_').trim();
    if (cleanName.isEmpty) return;

    final norm = entry.relativePath.replaceAll('\\', '/');
    final slash = norm.lastIndexOf('/');
    final newRelPath = slash < 0
        ? cleanName
        : '${norm.substring(0, slash)}/$cleanName';

    await _runBusy(() async {
      final updatedFiles = [
        for (final f in folder.files)
          f.id == entry.id
              ? FolderEntry(
                  id: f.id,
                  relativePath: newRelPath,
                  size: f.size,
                  mimeType: f.mimeType,
                )
              : f,
      ];
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: updatedFiles),
      );
      if (updated != null) _fallbackPost = updated;
    });
  }

  Future<void> _moveEntry(BuildContext context, FolderEntry entry) async {
    final norm = entry.relativePath.replaceAll('\\', '/');
    final slash = norm.lastIndexOf('/');
    final currentDir = slash < 0 ? '' : norm.substring(0, slash);
    final targetDir = await _promptMoveDestination(
      context,
      currentDir: currentDir,
    );
    if (targetDir == null || targetDir == currentDir || !mounted) return;

    final newRelPath = targetDir.isEmpty
        ? entry.fileName
        : '$targetDir/${entry.fileName}';

    await _runBusy(() async {
      final updatedFiles = [
        for (final f in folder.files)
          f.id == entry.id
              ? FolderEntry(
                  id: f.id,
                  relativePath: newRelPath,
                  size: f.size,
                  mimeType: f.mimeType,
                )
              : f,
      ];
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: updatedFiles),
      );
      if (updated != null) _fallbackPost = updated;
    });
  }

  Future<void> _replaceEntry(BuildContext context, FolderEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    await _runBusy(() async {
      final updated = await widget.feed.pickAndReplaceFolderEntry(
        _currentPost,
        entry,
      );
      if (updated != null && mounted) {
        _fallbackPost = updated;
        messenger.showSnackBar(SnackBar(content: Text(l.saved)));
      }
    });
  }

  Future<void> _deleteEntry(BuildContext context, FolderEntry entry) async {
    final l = context.l10n;
    final confirmed = await _confirmDelete(context, title: l.deleteFileTitle);
    if (!confirmed || !mounted) return;

    await _runBusy(() async {
      final remaining = folder.files.where((f) => f.id != entry.id).toList();
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: remaining),
        removedEntryIds: [entry.id],
      );
      if (!context.mounted) return;
      if (updated == null) {
        Navigator.of(context).pop();
      } else {
        _fallbackPost = updated;
      }
    });
  }

  Future<void> _renameSubdir(
    BuildContext context, {
    required String subName,
    required String subPath,
  }) async {
    final newName = await _promptName(context, initial: subName);
    if (newName == null || newName == subName || !mounted) return;
    final cleanName = newName.replaceAll(RegExp(r'[/\\]'), '_').trim();
    if (cleanName.isEmpty) return;

    final slash = subPath.lastIndexOf('/');
    final newSubPath = slash < 0
        ? cleanName
        : '${subPath.substring(0, slash)}/$cleanName';
    final oldPrefix = '$subPath/';
    final newPrefix = '$newSubPath/';

    await _runBusy(() async {
      final updatedFiles = [
        for (final f in folder.files)
          if (f.relativePath.replaceAll('\\', '/').startsWith(oldPrefix))
            FolderEntry(
              id: f.id,
              relativePath:
                  newPrefix +
                  f.relativePath
                      .replaceAll('\\', '/')
                      .substring(oldPrefix.length),
              size: f.size,
              mimeType: f.mimeType,
            )
          else
            f,
      ];
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: updatedFiles),
      );
      if (updated != null) _fallbackPost = updated;
    });
  }

  Future<void> _moveSubdir(
    BuildContext context, {
    required String subName,
    required String subPath,
  }) async {
    final slash = subPath.lastIndexOf('/');
    final parentDir = slash < 0 ? '' : subPath.substring(0, slash);
    final targetDir = await _promptMoveDestination(
      context,
      currentDir: parentDir,
      excludedSubtree: subPath,
    );
    if (targetDir == null || targetDir == parentDir || !mounted) return;

    final newSubPath = targetDir.isEmpty ? subName : '$targetDir/$subName';
    final oldPrefix = '$subPath/';
    final newPrefix = '$newSubPath/';

    await _runBusy(() async {
      final updatedFiles = [
        for (final f in folder.files)
          if (f.relativePath.replaceAll('\\', '/').startsWith(oldPrefix))
            FolderEntry(
              id: f.id,
              relativePath:
                  newPrefix +
                  f.relativePath
                      .replaceAll('\\', '/')
                      .substring(oldPrefix.length),
              size: f.size,
              mimeType: f.mimeType,
            )
          else
            f,
      ];
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: updatedFiles),
      );
      if (updated != null) _fallbackPost = updated;
    });
  }

  Future<void> _deleteSubdir(
    BuildContext context, {
    required String subPath,
  }) async {
    final l = context.l10n;
    final confirmed = await _confirmDelete(context, title: l.deleteFolderTitle);
    if (!confirmed || !mounted) return;

    final oldPrefix = '$subPath/';
    final removedIds = <String>[];
    final remaining = <FolderEntry>[];
    for (final f in folder.files) {
      if (f.relativePath.replaceAll('\\', '/').startsWith(oldPrefix)) {
        removedIds.add(f.id);
      } else {
        remaining.add(f);
      }
    }

    await _runBusy(() async {
      final updated = await widget.feed.updateFolderStructure(
        _currentPost,
        FolderAttachment(name: folder.name, files: remaining),
        removedEntryIds: removedIds,
      );
      if (!context.mounted) return;
      if (updated == null) {
        Navigator.of(context).pop();
      } else {
        _fallbackPost = updated;
      }
    });
  }

  Future<void> _addFilesToCurrentSubdir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    await _runBusy(() async {
      final updated = await widget.feed.pickAndAddFilesToFolder(
        _currentPost,
        targetSubdir: _currentSubdir,
      );
      if (updated != null && mounted) {
        _fallbackPost = updated;
        messenger.showSnackBar(SnackBar(content: Text(l.saved)));
      }
    });
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    try {
      final l = context.l10n;
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.rename),
          content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
            decoration: InputDecoration(
              labelText: l.nameTitle,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l.save),
            ),
          ],
        ),
      );
      return (result == null || result.isEmpty) ? null : result;
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _promptMoveDestination(
    BuildContext context, {
    required String currentDir,
    String? excludedSubtree,
  }) async {
    final allDirs = _allSubdirs().where((d) {
      if (excludedSubtree == null) return true;
      return d != excludedSubtree && !d.startsWith('$excludedSubtree/');
    }).toList();

    return showDialog<String>(
      context: context,
      builder: (context) => _MoveDestinationDialog(
        folderName: folder.name,
        existingDirs: allDirs,
        initialDir: currentDir,
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
  }) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(l.deleteItemText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
          onTap: isLast
              ? null
              : () => setState(() => _currentSubdir = pathForCrumb),
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
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
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
      createdAt: _currentPost.createdAt,
      senderDevice: _currentPost.senderDevice,
      attachment: attachment,
    );

    if (attachment.isImage) {
      await ImageViewerScreen.open(context, widget.feed, syntheticPost);
    } else if (attachment.isReadable) {
      var currentEntryId = entry.id;
      final currentRelPath = entry.relativePath;
      await TextViewerScreen.open(
        context,
        widget.feed,
        syntheticPost,
        onSaveContent: widget.feed.isReadOnly
            ? null
            : (bytes) async {
                final updatedPost = await widget.feed.replaceFolderEntry(
                  _currentPost,
                  currentEntryId,
                  bytes,
                  newRelativePath: currentRelPath,
                  mimeType: entry.mimeType,
                );
                if (updatedPost == null) return null;
                _fallbackPost = updatedPost;
                final newEntry = updatedPost.folder?.files
                    .where((e) => e.relativePath == currentRelPath)
                    .firstOrNull;
                if (newEntry != null) {
                  currentEntryId = newEntry.id;
                  return newEntry.toAttachment();
                }
                return null;
              },
      );
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
    final saved = await widget.feed.saveFolder(_currentPost);
    if (saved && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.savedFolder(folder.name))),
      );
    }
  }
}

class _MoveDestinationDialog extends StatefulWidget {
  const _MoveDestinationDialog({
    required this.folderName,
    required this.existingDirs,
    required this.initialDir,
  });

  final String folderName;
  final List<String> existingDirs;
  final String initialDir;

  @override
  State<_MoveDestinationDialog> createState() => _MoveDestinationDialogState();
}

class _MoveDestinationDialogState extends State<_MoveDestinationDialog> {
  late String _selected = widget.initialDir;
  final TextEditingController _customPath = TextEditingController();

  @override
  void dispose() {
    _customPath.dispose();
    super.dispose();
  }

  String _cleanPath(String raw) => raw
      .replaceAll('\\', '/')
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .join('/');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l.moveToTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.existingDirs.length,
                itemBuilder: (context, index) {
                  final dir = widget.existingDirs[index];
                  final label = dir.isEmpty
                      ? '${widget.folderName} (${l.folderRoot})'
                      : dir;
                  final selected =
                      _customPath.text.trim().isEmpty && _selected == dir;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    selected: selected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    leading: Icon(
                      dir.isEmpty ? Icons.folder_special : Icons.folder_outlined,
                      size: 20,
                    ),
                    title: Text(label),
                    onTap: () => setState(() {
                      _selected = dir;
                      _customPath.clear();
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customPath,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.newSubfolderHint,
                hintText: 'docs/archive',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final custom = _cleanPath(_customPath.text);
            Navigator.pop(
              context,
              _customPath.text.trim().isNotEmpty ? custom : _selected,
            );
          },
          child: Text(l.moveItem),
        ),
      ],
    );
  }
}
