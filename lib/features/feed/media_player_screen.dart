import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'player/playable_source.dart';

/// Видео и музыка прямо в приложении — системным проигрывателем (Android,
/// Windows, браузер). Если формат не поддерживается, предлагается открыть
/// файл в другом приложении.
///
/// Пока видео играет, экран не гаснет. «На весь экран» прячет заголовок
/// (на телефоне — и системные панели, горизонтальное видео поворачивается);
/// кнопки во время воспроизведения прячутся сами и появляются по нажатию.
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
  static const _hideDelay = Duration(seconds: 3);

  late final Attachment _attachment = widget.post.attachment!;
  PlayableSource? _source;
  VideoPlayerController? _player;
  Object? _error;
  bool _disposed = false;

  bool _fullscreen = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _awake = false;

  bool get _isVideo =>
      _attachment.isVideo && (_player?.value.size ?? Size.zero) != Size.zero;

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
      player.addListener(_onPlayerChanged);
      await player.play();
      setState(() => _player = player);
      _scheduleHide();
    } catch (e) {
      if (!_disposed) setState(() => _error = e);
    }
  }

  /// Экран не гаснет только пока видео действительно играет.
  void _onPlayerChanged() {
    final playing = _player?.value.isPlaying ?? false;
    final keepAwake = playing && _attachment.isVideo;
    if (keepAwake != _awake) {
      _awake = keepAwake;
      WakelockPlus.toggle(enable: keepAwake);
    }
    if (!playing && !_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_isVideo) return;
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && (_player?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _setFullscreen(bool value) async {
    setState(() => _fullscreen = value);
    _scheduleHide();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final landscape = (_player?.value.aspectRatio ?? 1) > 1;
      await SystemChrome.setPreferredOrientations(
        landscape
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : DeviceOrientation.values,
      );
    } else {
      await _restoreSystemUi();
    }
  }

  static Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    if (_awake) WakelockPlus.disable();
    if (_fullscreen &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _restoreSystemUi();
    }
    final player = _player;
    final source = _source;
    player?.removeListener(_onPlayerChanged);
    () async {
      await player?.dispose();
      await source?.dispose();
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // «Назад» сначала выходит из полноэкранного режима.
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen ? null : _appBar(context),
        body: _body(context),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    final l = context.l10n;
    final feed = widget.feed;
    final messenger = ScaffoldMessenger.of(context);
    return AppBar(
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
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Нажатие на видео показывает кнопки, на музыку — пауза/пуск.
            onTap: _isVideo
                ? (_controlsVisible
                      ? () => setState(() => _controlsVisible = false)
                      : _showControls)
                : () => player.value.isPlaying ? player.pause() : player.play(),
            child: Center(
              child: _isVideo
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _Controls(
                player: player,
                fullscreen: _fullscreen,
                onFullscreen: _isVideo
                    ? () => _setFullscreen(!_fullscreen)
                    : null,
                onInteraction: _scheduleHide,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Пуск/пауза, перемотка, время, «На весь экран».
class _Controls extends StatelessWidget {
  const _Controls({
    required this.player,
    required this.fullscreen,
    required this.onFullscreen,
    required this.onInteraction,
  });

  final VideoPlayerController player;
  final bool fullscreen;
  final VoidCallback? onFullscreen;

  /// Нажатие на кнопку — кнопки не прячутся ещё 3 секунды.
  final VoidCallback onInteraction;

  static String _time(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: player,
          builder: (context, value, _) {
            final total = value.duration.inMilliseconds.toDouble();
            final position = value.position.inMilliseconds
                .clamp(0, value.duration.inMilliseconds)
                .toDouble();
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    iconSize: 36,
                    tooltip: value.isPlaying ? l.pause : l.play,
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () {
                      value.isPlaying ? player.pause() : player.play();
                      onInteraction();
                    },
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
                          ? (ms) {
                              player.seekTo(Duration(milliseconds: ms.round()));
                              onInteraction();
                            }
                          : null,
                    ),
                  ),
                  Text(
                    _time(value.duration),
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (onFullscreen != null)
                    IconButton(
                      color: Colors.white,
                      tooltip: fullscreen ? l.exitFullscreen : l.fullscreen,
                      icon: Icon(
                        fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                      onPressed: onFullscreen,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
