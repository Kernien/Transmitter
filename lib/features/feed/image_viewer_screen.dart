import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';

/// Фото на весь экран: увеличение пальцами или колёсиком мыши, перемещение,
/// сохранение и «Поделиться».
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.feed, required this.post});

  final FeedController feed;
  final Post post;

  static Future<void> open(
    BuildContext context,
    FeedController feed,
    Post post,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImageViewerScreen(feed: feed, post: post),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final attachment = post.attachment!;
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (feed.canOpenExternally)
            IconButton(
              tooltip: l.openWith,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => feed.openExternally(post),
            ),
          if (feed.canShare)
            IconButton(
              tooltip: l.share,
              icon: const Icon(Icons.share),
              onPressed: () => feed.sharePost(post),
            ),
          IconButton(
            tooltip: l.save,
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (await feed.saveAttachment(post)) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l.savedFile(attachment.fileName))),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: feed.previews.load(attachment),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.hasError) {
            return Center(
              child: Text(
                l.describeError(snapshot.error!),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return InteractiveViewer(
            maxScale: 8,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  l.imageUnsupported,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
