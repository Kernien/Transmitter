import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/l10n.dart';
import '../../domain/post.dart';
import 'feed_controller.dart';
import 'player/playable_source.dart';

/// Видео и музыка прямо в приложении — плеером media_kit (libmpv: почти любые
/// форматы, в том числе .avi и .mkv; в браузере — плеер браузера). Если файл
/// не играет, предлагается открыть его в другом приложении.
///
/// Пока видео играет, экран не гаснет; свёрнутое приложение ставит видео на
/// паузу, а музыка играет дальше (и при выключенном экране). «На весь экран»
/// прячет заголовок (на телефоне — и системные панели, горизонтальное видео
/// поворачивается); кнопки во время воспроизведения прячутся сами и
/// появляются по нажатию.
class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key, required this.feed, required this.post});

  final FeedController feed;
  final Post post;

  /// Встроенный плеер есть на Android, Windows и в браузере; на Linux —
  /// только «Открыть в другом приложении» (libmpv пришлось бы класть в
  /// AppImage).
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Вызывается один раз при запуске приложения (в `main.dart`).
  static void initialize() {
    if (isSupported) MediaKit.ensureInitialized();
  }

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
  Player? _player;
  VideoController? _video;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Object? _error;
  bool _disposed = false;

  /// Файл открылся: известна длительность.
  bool _loaded = false;
  bool _hasPicture = false;

  bool _fullscreen = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  bool get _isVideo => _attachment.isVideo && _hasPicture;

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
      final player = Player();
      _player = player;
      // Вывод картинки подключается до открытия файла, иначе первые кадры
      // теряются. Для музыки он не нужен.
      if (_attachment.isVideo) _video = VideoController(player);
      final stream = player.stream;
      _subscriptions.addAll([
        stream.playing.listen(_onPlayingChanged),
        stream.duration.listen((d) {
          if (d > Duration.zero && !_loaded && mounted) {
            setState(() => _loaded = true);
            _scheduleHide();
          }
        }),
        stream.width.listen((w) {
          final picture = (w ?? 0) > 0;
          if (picture != _hasPicture && mounted) {
            setState(() => _hasPicture = picture);
            _scheduleHide();
          }
        }),
        // Ошибка до начала воспроизведения — файл не открылся.
        stream.error.listen((e) {
          if (!_loaded && mounted) setState(() => _error = e);
        }),
      ]);
      await player.open(source.media());
      if (mounted) setState(() {});
    } catch (e) {
      if (!_disposed) setState(() => _error = e);
    }
  }

  void _onPlayingChanged(bool playing) {
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
      if (mounted && (_player?.state.playing ?? false)) {
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
      final state = _player?.state;
      final landscape = (state?.width ?? 1) > (state?.height ?? 1);
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
    if (_fullscreen &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _restoreSystemUi();
    }
    final player = _player;
    final source = _source;
    () async {
      for (final s in _subscriptions) {
        await s.cancel();
      }
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
    final video = _video;
    if (player == null || !_loaded) {
      return Stack(
        children: [
          // Картинка должна быть в дереве с самого начала: так media_kit
          // узнаёт её размер.
          if (video != null) Positioned.fill(child: _picture(video)),
          const Center(child: CircularProgressIndicator()),
        ],
      );
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
                : player.playOrPause,
            child: video != null && _isVideo
                ? _picture(video)
                : const Center(
                    child: Icon(
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

  /// Картинка видео. Пока играет, экран не гаснет; в фоне — пауза.
  static Widget _picture(VideoController video) =>
      Video(controller: video, controls: NoVideoControls);
}

/// Пуск/пауза, перемотка, время, «На весь экран».
class _Controls extends StatelessWidget {
  const _Controls({
    required this.player,
    required this.fullscreen,
    required this.onFullscreen,
    required this.onInteraction,
  });

  final Player player;
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
    final stream = player.stream;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Row(
            children: [
              StreamBuilder(
                stream: stream.playing,
                initialData: player.state.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return IconButton(
                    color: Colors.white,
                    iconSize: 36,
                    tooltip: playing ? l.pause : l.play,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      player.playOrPause();
                      onInteraction();
                    },
                  );
                },
              ),
              Expanded(
                child: StreamBuilder(
                  stream: stream.position,
                  initialData: player.state.position,
                  builder: (context, snapshot) {
                    final duration = player.state.duration;
                    final position = snapshot.data ?? Duration.zero;
                    final total = duration.inMilliseconds.toDouble();
                    return Row(
                      children: [
                        Text(
                          _time(position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: Slider(
                            value: total > 0
                                ? position.inMilliseconds
                                      .clamp(0, duration.inMilliseconds)
                                      .toDouble()
                                : 0,
                            max: total > 0 ? total : 1,
                            onChanged: total > 0
                                ? (ms) {
                                    player.seek(
                                      Duration(milliseconds: ms.round()),
                                    );
                                    onInteraction();
                                  }
                                : null,
                          ),
                        ),
                        Text(
                          _time(duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
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
        ),
      ),
    );
  }
}
