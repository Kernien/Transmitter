import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_config.dart';
import '../../app/vault_session_factory.dart';
import '../../core/files/file_transfer_service.dart';
import '../../core/vault/vault_key.dart';
import '../../data/post_repository.dart';
import 'feed_controller.dart';
import 'widgets/compose_bar.dart';
import 'widgets/post_tile.dart';

/// Лента постов одной базы.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.vaultKey});

  final VaultKey vaultKey;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final Future<PostRepository> _repository =
      context.read<VaultSessionFactory>().open(widget.vaultKey);

  String get _title => widget.vaultKey.label.isEmpty ? 'База' : widget.vaultKey.label;

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
                  ? Text('Не удалось открыть базу: ${snapshot.error}')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return ChangeNotifierProvider(
          create: (context) => FeedController(
            repository,
            files: context.read<FileTransferService>(),
            pollInterval: AppConfig.pollInterval,
          )..start(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmClear(context),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Очистить ленту'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: const _FileDropZone(child: _FeedBody()),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final feed = context.read<FeedController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить ленту?'),
        content: const Text(
          'Все сообщения и файлы этой базы будут удалены из облака '
          'на всех устройствах. Отменить это нельзя.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить всё')),
        ],
      ),
    );
    if (confirmed == true) await feed.clearAll();
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
    final theme = Theme.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final files = details.files.whereType<DropItemFile>().toList();
        if (files.isNotEmpty) context.read<FeedController>().sendDroppedFiles(files);
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
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Отпустите, чтобы отправить (до 25 МБ на файл)',
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
            content: Text(feed.error!),
            actions: [
              TextButton(onPressed: feed.refresh, child: const Text('Повторить')),
            ],
          ),
        Expanded(
          child: feed.isInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : posts.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Пока пусто. Отправьте сообщение или перетащите сюда файл.',
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
        const ComposeBar(),
      ],
    );
  }
}
