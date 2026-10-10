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

  @override
  Widget build(BuildContext context) {
    final label = widget.vaultKey.label;
    return Scaffold(
      appBar: AppBar(title: Text(label.isEmpty ? 'База' : label)),
      body: FutureBuilder<PostRepository>(
        future: _repository,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Не удалось открыть базу: ${snapshot.error}'));
          }
          final repository = snapshot.data;
          if (repository == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ChangeNotifierProvider(
            create: (context) => FeedController(
              repository,
              files: context.read<FileTransferService>(),
              pollInterval: AppConfig.pollInterval,
            )..start(),
            child: const _FeedBody(),
          );
        },
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
                  ? const Center(child: Text('Пока пусто. Отправьте первое сообщение.'))
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
