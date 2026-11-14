import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_config.dart';
import '../../app/app_lock_controller.dart';
import '../../app/l10n.dart';
import '../../app/vault_session_factory.dart';
import '../../app/widgets/content_width.dart';
import '../../core/files/external_opener.dart';
import '../../core/files/file_transfer_service.dart';
import '../../core/files/media_picker.dart';
import '../../core/share/outgoing_share.dart';
import '../../core/vault/reader_key.dart';
import '../../core/vault/vault_key.dart';
import '../../data/post_repository.dart';
import '../../data/public_board_repository.dart';
import '../../domain/post.dart';
import '../vaults/vaults_controller.dart';
import '../vaults/vaults_screen.dart' show kWideScreenBreakpoint;
import 'feed_controller.dart';
import 'folder_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'media_player_screen.dart';
import 'selection_exporter.dart';
import 'text_viewer_screen.dart';
import 'widgets/compose_bar.dart';
import 'widgets/post_tile.dart';

enum _ViewMode { feed, files }

/// Лента постов одной базы или публичной доски.
class FeedScreen extends StatefulWidget {
  /// База владельца: всё можно.
  FeedScreen.vault(VaultKey vault, {super.key, this.embedded = false})
    : label = vault.label,
      pollInterval = AppConfig.pollInterval,
      liveLabel = null,
      onOwnerLabel = null,
      boardKey = vault,
      _open = ((sessions) => sessions.open(vault));

  /// Публичная доска у читателя: только чтение, без входа в облако.
  ///
  /// [liveLabel] — текущее название доски (оно может смениться, пока лента
  /// открыта), [onOwnerLabel] — владелец прислал новое название.
  FeedScreen.board(
    ReaderKey board, {
    super.key,
    this.liveLabel,
    this.onOwnerLabel,
    this.embedded = false,
  }) : label = board.label,
       pollInterval = AppConfig.boardPollInterval,
       boardKey = board,
       _open = ((sessions) async => sessions.openAsReader(board));

  final String label;
  final String Function(BuildContext context)? liveLabel;
  final void Function(String ownerLabel)? onOwnerLabel;
  final Duration pollInterval;
  final Object? boardKey;
  /// Встроена ли лента в правую панель широкого экрана (без кнопки «Назад»).
  final bool embedded;
  final Future<PostRepository> Function(VaultSessionFactory) _open;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final Future<PostRepository> _repository = widget._open(
    context.read<VaultSessionFactory>(),
  );
  bool _poppingOnResize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Если лента была открыта отдельным экраном в узком окне, а затем окно
    // растянули до двухпанельного режима, закрываем этот маршрут, чтобы
    // показать обе панели (список досок слева + эту же ленту справа).
    if (!widget.embedded &&
        !_poppingOnResize &&
        MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint) {
      _poppingOnResize = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == true &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          _poppingOnResize = false;
        }
      });
    }
  }

  String get _title {
    final label = widget.liveLabel?.call(context) ?? widget.label;
    return label.isEmpty ? context.l10n.vaultFallbackTitle : label;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final exportTexts = ExportTexts(
      textFileName: l.exportTextFileName,
      fileNote: l.exportFileNote,
    );
    return FutureBuilder<PostRepository>(
      future: _repository,
      builder: (context, snapshot) {
        final repository = snapshot.data;
        if (repository == null) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !widget.embedded,
              title: Text(_title),
            ),
            body: Center(
              child: snapshot.hasError
                  ? Text(
                      context.l10n.openVaultFailed(
                        context.l10n.describeError(snapshot.error!),
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return ChangeNotifierProvider(
          create: (context) {
            final feed = FeedController(
              repository,
              files: context.read<FileTransferService>(),
              media: context.read<MediaPicker>(),
              opener: context.read<ExternalOpener>(),
              share: context.read<ShareSender>(),
              pollInterval: widget.pollInterval,
              exportTexts: exportTexts,
            )..start();
            final onOwnerLabel = widget.onOwnerLabel;
            if (onOwnerLabel != null && repository is PublicBoardRepository) {
              feed.addListener(() {
                final ownerLabel = repository.ownerLabel;
                if (ownerLabel != null) onOwnerLabel(ownerLabel);
              });
            }
            return feed;
          },
          child: _FeedView(
            title: _title,
            boardKey: widget.boardKey,
            embedded: widget.embedded,
          ),
        );
      },
    );
  }
}

class _FeedView extends StatefulWidget {
  const _FeedView({
    required this.title,
    this.boardKey,
    this.embedded = false,
  });

  final String title;
  final Object? boardKey;
  final bool embedded;

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  _ViewMode _viewMode = _ViewMode.feed;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selecting = context.select<FeedController, bool>(
      (f) => f.isSelecting,
    );
    final l = context.l10n;

    final PreferredSizeWidget appBar;
    if (selecting) {
      appBar = _selectionAppBar(context);
    } else if (_isSearching) {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (val) =>
              setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l.clearSearch,
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      );
    } else {
      appBar = _normalAppBar(context);
    }

    return PopScope(
      canPop: !selecting && !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (selecting) {
            context.read<FeedController>().clearSelection();
          } else if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          }
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: _FileDropZone(
          child: ContentWidth(
            child: _FeedBody(
              viewMode: _viewMode,
              searchQuery: _searchQuery,
              onModeChanged: (mode) => setState(() => _viewMode = mode),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _normalAppBar(BuildContext context) {
    final vaults = Provider.of<VaultsController?>(context);
    final key = widget.boardKey;
    final isPinned = key != null && vaults != null && vaults.isPinned(key);
    final isReadOnly = context.read<FeedController>().isReadOnly;

    return AppBar(
      automaticallyImplyLeading: !widget.embedded,
      title: Text(widget.title),
      actions: [
        if (isReadOnly)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(
              avatar: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(context.l10n.readOnly),
            ),
          ),
        IconButton(
          tooltip: context.l10n.searchAction,
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
        if (key != null && vaults != null)
          IconButton(
            tooltip: isPinned ? context.l10n.unpinVault : context.l10n.pinVault,
            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => vaults.togglePinned(key),
          ),
        if (!isReadOnly)
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') _confirmClear(context);
              if (val == 'pin' && key != null && vaults != null) {
                vaults.togglePinned(key);
              }
            },
            itemBuilder: (_) => [
              if (key != null && vaults != null)
                CheckedPopupMenuItem<String>(
                  value: 'pin',
                  checked: isPinned,
                  child: Text(context.l10n.pinVault),
                ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: Text(context.l10n.clearFeed),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          )
        else if (key != null && vaults != null)
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'pin') vaults.togglePinned(key);
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String>(
                value: 'pin',
                checked: isPinned,
                child: Text(context.l10n.pinVault),
              ),
            ],
          ),
      ],
    );
  }

  AppBar _selectionAppBar(BuildContext context) {
    final l = context.l10n;
    final feed = context.watch<FeedController>();
    final busy = feed.isBulkBusy;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      leading: IconButton(
        tooltip: l.clearSelection,
        icon: const Icon(Icons.close),
        onPressed: feed.clearSelection,
      ),
      title: Text(l.selectedCount(feed.selectedCount)),
      actions: [
        IconButton(
          tooltip: l.selectAll,
          icon: const Icon(Icons.select_all),
          onPressed: busy ? null : feed.selectAll,
        ),
        if (feed.canShare)
          IconButton(
            tooltip: l.share,
            icon: const Icon(Icons.share),
            onPressed: busy ? null : feed.shareSelected,
          ),
        busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: l.downloadSelected,
                icon: const Icon(Icons.download),
                onPressed: () => _saveSelected(context),
              ),
        if (!feed.isReadOnly)
          IconButton(
            tooltip: l.deleteSelected,
            icon: const Icon(Icons.delete_outline),
            onPressed: busy ? null : () => _confirmDeleteSelected(context),
          ),
      ],
    );
  }

  Future<void> _saveSelected(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.saved;
    if (await context.read<FeedController>().saveSelected()) {
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final l = context.l10n;
    final feed = context.read<FeedController>();
    final confirmed = await _confirm(
      context,
      title: l.deleteSelectedTitle(feed.selectedCount),
      text: l.deleteSelectedText,
      action: l.delete,
    );
    if (confirmed) await feed.deleteSelected();
  }

  Future<void> _confirmClear(BuildContext context) async {
    final feed = context.read<FeedController>();
    final confirmed = await _confirm(
      context,
      title: context.l10n.clearFeedTitle,
      text: context.l10n.clearFeedText,
      action: context.l10n.deleteAll,
    );
    if (confirmed) await feed.clearAll();
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String text,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// Принимает файлы, перетащенные в окно (Windows, веб).
class _FileDropZone extends StatefulWidget {
  const _FileDropZone({required this.child});

  final Widget child;

  @override
  State<_FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<_FileDropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    // На доску у читателя ничего не отправить.
    if (context.read<FeedController>().isReadOnly) return widget.child;
    final theme = Theme.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        // Окно закрыто ПИН-кодом: файлы, брошенные поверх него, не принимаем.
        if (context.read<AppLockController?>()?.isLocked ?? false) return;
        final files = details.files.whereType<DropItemFile>().toList();
        if (files.isNotEmpty) {
          context.read<FeedController>().sendDroppedFiles(files);
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    context.l10n.dropHintOf(
                      context.read<FeedController>().maxFileSize,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.viewMode,
    required this.searchQuery,
    required this.onModeChanged,
  });

  final _ViewMode viewMode;
  final String searchQuery;
  final ValueChanged<_ViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final posts = feed.posts;
    final l = context.l10n;

    return Column(
      children: [
        if (feed.error != null)
          MaterialBanner(
            content: Text(context.l10n.describeError(feed.error!)),
            actions: [
              TextButton(
                onPressed: feed.refresh,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Center(
            child: SegmentedButton<_ViewMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _ViewMode.feed,
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text(l.feedTab),
                ),
                ButtonSegment(
                  value: _ViewMode.files,
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(l.filesTab),
                ),
              ],
              selected: {viewMode},
              onSelectionChanged: (set) => onModeChanged(set.first),
            ),
          ),
        ),
        Expanded(
          child: viewMode == _ViewMode.files
              ? _FilesListView(feed: feed, searchQuery: searchQuery)
              : _buildFeedList(context, feed, posts, l),
        ),
        if (viewMode == _ViewMode.feed &&
            !feed.isReadOnly &&
            searchQuery.isEmpty)
          const ComposeBar(),
      ],
    );
  }

  Widget _buildFeedList(
    BuildContext context,
    FeedController feed,
    List<Post> posts,
    AppLocalizations l,
  ) {
    if (feed.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return feed.error != null
          ? const SizedBox.shrink()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  feed.isReadOnly ? l.boardEmpty : l.feedEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
    }
    final q = searchQuery;
    final filtered = q.isEmpty
        ? posts
        : posts.where((p) {
            if (p.text.toLowerCase().contains(q)) return true;
            if (p.note?.text.toLowerCase().contains(q) == true) return true;
            if (p.attachment?.fileName.toLowerCase().contains(q) == true) {
              return true;
            }
            if (p.folder?.name.toLowerCase().contains(q) == true) return true;
            if (p.folder?.files.any(
                  (f) =>
                      f.fileName.toLowerCase().contains(q) ||
                      f.relativePath.toLowerCase().contains(q),
                ) ==
                true) {
              return true;
            }
            return false;
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.searchNoResults, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      reverse: q.isEmpty,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final post =
            q.isEmpty ? filtered[filtered.length - 1 - i] : filtered[i];
        return PostTile(post: post);
      },
    );
  }
}

class _FileItem {
  _FileItem({
    required this.post,
    this.attachment,
    this.folder,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  final Post post;
  final Attachment? attachment;
  final FolderAttachment? folder;
  final String name;
  final int size;
  final DateTime createdAt;

  bool get isFolder => folder != null;
}

class _FilesListView extends StatelessWidget {
  const _FilesListView({
    required this.feed,
    required this.searchQuery,
  });

  final FeedController feed;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final isReadOnly = feed.isReadOnly;

    final allItems = <_FileItem>[];
    for (final post in feed.posts) {
      if (post.attachment case final att?) {
        allItems.add(
          _FileItem(
            post: post,
            attachment: att,
            name: att.fileName,
            size: att.size,
            createdAt: post.createdAt,
          ),
        );
      } else if (post.folder case final fol?) {
        final totalSize = fol.files.fold<int>(0, (sum, f) => sum + f.size);
        allItems.add(
          _FileItem(
            post: post,
            folder: fol,
            name: fol.name,
            size: totalSize,
            createdAt: post.createdAt,
          ),
        );
      }
    }

    // Сортировка: от новых к старым
    allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final q = searchQuery;
    final items = q.isEmpty
        ? allItems
        : allItems.where((it) {
            if (it.name.toLowerCase().contains(q)) return true;
            if (it.isFolder) {
              return it.folder!.files.any(
                (f) =>
                    f.fileName.toLowerCase().contains(q) ||
                    f.relativePath.toLowerCase().contains(q),
              );
            }
            return false;
          }).toList();

    if (allItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.noFilesYet, textAlign: TextAlign.center),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.searchNoResults, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final post = item.post;
        final isPending = post.id.startsWith('pending_');

        IconData iconData;
        Color? iconColor;
        if (item.isFolder) {
          iconData = Icons.folder;
          iconColor = theme.colorScheme.primary;
        } else if (item.attachment?.isImage ?? false) {
          iconData = Icons.image_outlined;
        } else if (item.attachment?.isVideo ?? false) {
          iconData = Icons.videocam_outlined;
        } else if (item.attachment?.isAudio ?? false) {
          iconData = Icons.audiotrack_outlined;
        } else {
          iconData = Icons.description_outlined;
        }

        final subtitleText = item.isFolder
            ? '${l.folderFilesCount(item.folder!.files.length)} · ${l.fileSize(item.size)}'
            : '${l.fileSize(item.size)} · ${_formatDate(item.createdAt)}';

        return ListTile(
          leading: Icon(iconData, color: iconColor),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitleText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: isPending ? null : () => _openItem(context, feed, item),
          trailing: isPending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton<_FileItemAction>(
                  tooltip: l.actions,
                  onSelected: (action) =>
                      _onAction(context, feed, item, action),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _FileItemAction.save,
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            item.isFolder ? l.saveFolder : l.actionSaveFile,
                          ),
                        ],
                      ),
                    ),
                    if (feed.canOpenExternally && !item.isFolder)
                      PopupMenuItem(
                        value: _FileItemAction.openWith,
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new, size: 20),
                            const SizedBox(width: 12),
                            Text(l.openWith),
                          ],
                        ),
                      ),
                    if (!isReadOnly) ...[
                      PopupMenuItem(
                        value: _FileItemAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l.delete,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  void _openItem(BuildContext context, FeedController feed, _FileItem item) {
    final post = item.post;
    if (item.isFolder) {
      FolderViewerScreen.open(context, feed, post);
    } else if (item.attachment?.isImage ?? false) {
      ImageViewerScreen.open(context, feed, post);
    } else if (item.attachment?.isReadable ?? false) {
      TextViewerScreen.open(context, feed, post);
    } else if ((item.attachment?.isVideo ?? false) ||
        (item.attachment?.isAudio ?? false)) {
      MediaPlayerScreen.open(context, feed, post);
    } else {
      feed.saveAttachment(post);
    }
  }

  Future<void> _onAction(
    BuildContext context,
    FeedController feed,
    _FileItem item,
    _FileItemAction action,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _FileItemAction.save:
        if (item.isFolder) {
          if (await feed.saveFolder(item.post)) {
            messenger.showSnackBar(
              SnackBar(content: Text(l.savedFolder(item.name))),
            );
          }
        } else {
          if (await feed.saveAttachment(item.post)) {
            messenger.showSnackBar(
              SnackBar(content: Text(l.savedFile(item.name))),
            );
          }
        }
      case _FileItemAction.openWith:
        await feed.openExternally(item.post);
      case _FileItemAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              item.isFolder ? l.deleteFolderTitle : l.deleteFileTitle,
            ),
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
        if (confirmed == true) {
          await feed.delete(item.post);
        }
    }
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

enum _FileItemAction { save, openWith, delete }
