import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'player/playable_source.dart';

/// Видео и музыка прямо в приложении — системным проигрывателем (Android,
/// Windows, браузер). Если формат не поддерживается, предлагается открыть
/// файл в другом приложении.
class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key, required this.feed, required this.post});

  final FeedController feed;
  final Post post;

  /// Встроенный плеер есть на Android, Windows и в браузере; на Linux —
  /// только «Открыть в другом приложении».
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> open(
    BuildContext context,
    FeedController feed,
    Post post,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MediaPlayerScreen(feed: feed, post: post),
    ),
  );

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  late final Attachment _attachment = widget.post.attachment!;
  PlayableSource? _source;
  VideoPlayerController? _player;
  Object? _error;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final bytes = await widget.feed.previews.load(_attachment);
      final source = await preparePlayable(
        fileName: _attachment.fileName,
        bytes: bytes,
        mimeType: _attachment.mimeType,
      );
      if (_disposed) {
        await source.dispose();
        return;
      }
      _source = source;
      final player = source.controller();
      await player.initialize();
      if (_disposed) {
        await player.dispose();
        return;
      }
      await player.play();
      setState(() => _player = player);
    } catch (e) {
      if (!_disposed) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final player = _player;
    final source = _source;
    () async {
      await player?.dispose();
      await source?.dispose();
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final feed = widget.feed;
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_attachment.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (feed.canOpenExternally)
            IconButton(
              tooltip: l.openWith,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => feed.openExternally(widget.post),
            ),
          if (feed.canShare)
            IconButton(
              tooltip: l.share,
              icon: const Icon(Icons.share),
              onPressed: () => feed.sharePost(widget.post),
            ),
          IconButton(
            tooltip: l.save,
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (await feed.saveAttachment(widget.post)) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l.savedFile(_attachment.fileName))),
                );
              }
            },
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.playbackFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (widget.feed.canOpenExternally) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.openWith),
                  onPressed: () => widget.feed.openExternally(widget.post),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final player = _player;
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () =>
                player.value.isPlaying ? player.pause() : player.play(),
            child: Center(
              child: _attachment.isVideo && player.value.size != Size.zero
                  ? AspectRatio(
                      aspectRatio: player.value.aspectRatio,
                      child: VideoPlayer(player),
                    )
                  : const Icon(
                      Icons.music_note,
                      size: 120,
                      color: Colors.white54,
                    ),
            ),
          ),
        ),
        _Controls(player: player),
      ],
    );
  }
}

/// Пуск/пауза, перемотка и время.
class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final VideoPlayerController player;

  static String _time(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ValueListenableBuilder(
        valueListenable: player,
        builder: (context, value, _) {
          final total = value.duration.inMilliseconds.toDouble();
          final position = value.position.inMilliseconds
              .clamp(0, value.duration.inMilliseconds)
              .toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
            child: Row(
              children: [
                IconButton(
                  color: Colors.white,
                  iconSize: 36,
                  tooltip: value.isPlaying
                      ? context.l10n.pause
                      : context.l10n.play,
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () =>
                      value.isPlaying ? player.pause() : player.play(),
                ),
                Text(
                  _time(value.position),
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: total > 0 ? position : 0,
                    max: total > 0 ? total : 1,
                    onChanged: total > 0
                        ? (ms) =>
                              player.seekTo(Duration(milliseconds: ms.round()))
                        : null,
                  ),
                ),
                Text(
                  _time(value.duration),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
