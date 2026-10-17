import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_config.dart';
import '../../app/l10n.dart';
import '../../app/vault_session_factory.dart';
import '../../app/widgets/content_width.dart';
import '../../core/files/file_transfer_service.dart';
import '../../core/files/media_picker.dart';
import '../../core/share/outgoing_share.dart';
import '../../core/vault/reader_key.dart';
import '../../core/vault/vault_key.dart';
import '../../data/post_repository.dart';
import '../../data/public_board_repository.dart';
import 'feed_controller.dart';
import 'selection_exporter.dart';
import 'widgets/compose_bar.dart';
import 'widgets/post_tile.dart';

/// Лента постов одной базы или публичной доски.
class FeedScreen extends StatefulWidget {
  /// База владельца: всё можно.
  FeedScreen.vault(VaultKey vault, {super.key})
    : label = vault.label,
      pollInterval = AppConfig.pollInterval,
      liveLabel = null,
      onOwnerLabel = null,
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
  }) : label = board.label,
       pollInterval = AppConfig.boardPollInterval,
       _open = ((sessions) async => sessions.openAsReader(board));

  final String label;
  final String Function(BuildContext context)? liveLabel;
  final void Function(String ownerLabel)? onOwnerLabel;
  final Duration pollInterval;
  final Future<PostRepository> Function(VaultSessionFactory) _open;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final Future<PostRepository> _repository = widget._open(
    context.read<VaultSessionFactory>(),
  );

  String get _title {
    final label = widget.liveLabel?.call(context) ?? widget.label;
    return label.isEmpty ? context.l10n.vaultFallbackTitle : label;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PostRepository>(
      future: _repository,
      builder: (context, snapshot) {
        final repository = snapshot.data;
        if (repository == null) {
          return Scaffold(
            appBar: AppBar(title: Text(_title)),
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
              share: context.read<ShareSender>(),
              pollInterval: widget.pollInterval,
              exportTexts: ExportTexts(
                textFileName: context.l10n.exportTextFileName,
                fileNote: context.l10n.exportFileNote,
              ),
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
          child: _FeedView(title: _title),
        );
      },
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final selecting = context.select<FeedController, bool>(
      (f) => f.isSelecting,
    );
    return PopScope(
      // «Назад» в режиме выделения снимает выделение, а не закрывает ленту.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<FeedController>().clearSelection();
      },
      child: Scaffold(
        appBar: selecting ? _selectionAppBar(context) : _normalAppBar(context),
        body: const _FileDropZone(child: ContentWidth(child: _FeedBody())),
      ),
    );
  }

  AppBar _normalAppBar(BuildContext context) => AppBar(
    title: Text(title),
    actions: [
      if (context.read<FeedController>().isReadOnly)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Chip(
            avatar: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(context.l10n.readOnly),
          ),
        )
      else
        PopupMenuButton<String>(
          onSelected: (_) => _confirmClear(context),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'clear',
              child: ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(context.l10n.clearFeed),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
    ],
  );

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
                    context.l10n.dropHint(
                      context.l10n.sizeLimitOf(
                        context.read<FeedController>().maxFileSize,
                      ),
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
  const _FeedBody();

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final posts = feed.posts;

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
        Expanded(
          child: feed.isInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : posts.isEmpty
              // При ошибке (нет сети, доступ к доске закрыт) достаточно
              // баннера: подсказка «пока пусто» сбивала бы с толку.
              ? feed.error != null
                    ? const SizedBox.shrink()
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            feed.isReadOnly
                                ? context.l10n.boardEmpty
                                : context.l10n.feedEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, i) =>
                      PostTile(post: posts[posts.length - 1 - i]),
                ),
        ),
        if (!feed.isReadOnly) const ComposeBar(),
      ],
    );
  }
}
