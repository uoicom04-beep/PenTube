import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show MuxedStreamInfo;

import '../core/fmt.dart';
import '../core/settings.dart';
import '../core/strings.dart';
import '../services/audio_handler.dart';
import '../services/downloads.dart';
import '../services/net.dart';
import '../services/models.dart';
import '../services/pip.dart';
import '../services/store.dart';
import '../services/yt.dart';
import '../widgets/video_tile.dart';
import 'channel_screen.dart';

class WatchScreen extends StatefulWidget {
  final VideoRef video;
  const WatchScreen({super.key, required this.video});
  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  late VideoRef _video = widget.video;
  VideoPlayerController? _vc;
  List<MuxedStreamInfo> _muxed = const [];
  int _height = 0;
  File? _local; // offline copy, if downloaded

  bool _loading = true;
  bool _audioMode = false; // user picked "listen only"
  bool _bg = false; // auto-switched to audio because the app left the screen
  bool _controls = true;
  bool _full = false;
  bool _ended = false;
  bool _relatedLoading = false;
  String? _error;
  Timer? _hideT, _leaveT;
  List<VideoRef> _related = [];
  final Set<String> _played = {};
  int _gen = 0; // invalidates stale async work
  AppLifecycleState _life = AppLifecycleState.resumed;

  bool get _audioPath => _audioMode || _bg || (_muxed.isEmpty && _local == null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Pip.inPip.addListener(_pipChanged);
    _open(_video);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Pip.inPip.removeListener(_pipChanged);
    _hideT?.cancel();
    _leaveT?.cancel();
    _gen++;
    final c = _vc;
    _vc = null;
    c?.removeListener(_onTick);
    c?.dispose();
    audioHandler.onCompleted = null;
    audioHandler.stop();
    Pip.arm(false);
    WakelockPlus.disable();
    if (_full) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- playback

  Duration _pos() => (_audioMode || _bg) ? audioHandler.position : (_vc?.value.position ?? Duration.zero);

  Future<void> _disposeVideo() async {
    final c = _vc;
    _vc = null;
    if (c != null) {
      c.removeListener(_onTick);
      await c.dispose();
    }
    WakelockPlus.disable();
  }

  Future<void> _open(VideoRef v, {Duration start = Duration.zero, bool autoplay = true}) async {
    final gen = ++_gen;
    _video = v;
    _played.add(v.id);
    _ended = false;
    _error = null;
    _loading = true;
    if (mounted) setState(() {});
    await _disposeVideo();
    Store.I.addHistory(v);
    try {
      _local = Downloads.I.file(v.id);
      _muxed = _local != null ? const [] : await Yt.muxed(v.id);
      if (gen != _gen || !mounted) return;
      if (_audioPath) {
        await _startAudio(start, gen);
      } else {
        await audioHandler.stop();
        await _startVideo(start, gen, autoplay);
      }
      if (gen != _gen || !mounted) return;
      setState(() => _loading = false);
      if (!Settings.I.saver) _loadRelated();
    } catch (e) {
      if (gen != _gen || !mounted) return;
      Yt.forget(v.id);
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  MuxedStreamInfo _pick() {
    final target = _height > 0 ? _height : Settings.I.quality;
    MuxedStreamInfo? best;
    for (final m in _muxed) {
      if (m.videoResolution.height <= target) best = m;
    }
    return best ?? _muxed.first;
  }

  Future<void> _startVideo(Duration start, int gen, bool autoplay) async {
    final VideoPlayerController c;
    if (_local != null) {
      c = VideoPlayerController.file(_local!);
    } else {
      final m = _pick();
      c = VideoPlayerController.networkUrl(await Proxy.wrap(m.url, m.size.totalBytes, 'video/mp4'));
    }
    await c.initialize();
    if (gen != _gen || !mounted) {
      await c.dispose();
      return;
    }
    if (start > Duration.zero) await c.seekTo(start);
    c.addListener(_onTick);
    _vc = c;
    if (autoplay) await c.play();
    WakelockPlus.enable();
    Pip.arm(Settings.I.leaveMode == LeaveMode.pip);
    _poke();
  }

  Future<void> _startAudio(Duration start, int gen) async {
    String url;
    if (_local != null) {
      url = _local!.path;
    } else {
      final a = await Yt.audio(_video.id, low: Settings.I.saver);
      if (gen != _gen || !mounted) return;
      url = (await Proxy.wrap(a.url, a.size.totalBytes, 'audio/mp4')).toString();
    }
    audioHandler.onCompleted = _onEnded;
    await audioHandler.load(
      url,
      MediaItem(
        id: _video.id,
        title: _video.title,
        artist: _video.author,
        duration: _video.seconds > 0 ? Duration(seconds: _video.seconds) : null,
        artUri: Uri.parse(_video.thumb),
      ),
      start: start,
    );
    unawaited(audioHandler.play());
    WakelockPlus.disable();
    Pip.arm(false);
  }

  void _onTick() {
    final v = _vc?.value;
    if (v == null) return;
    if (v.hasError && _error == null) {
      Yt.forget(_video.id);
      setState(() => _error = v.errorDescription ?? 'error');
      return;
    }
    if (!_ended &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 300) &&
        !v.isPlaying) {
      _ended = true;
      _onEnded();
    }
  }

  Future<void> _onEnded() async {
    if (!Settings.I.autoplay || !mounted) return;
    if (_local != null) {
      final n = Downloads.I.items.where((r) => !_played.contains(r.id)).firstOrNull;
      if (n != null) _goto(n);
      return;
    }
    if (_related.isEmpty) await _loadRelated();
    if (!mounted) return;
    final next = _related.where((r) => !_played.contains(r.id)).firstOrNull;
    if (next != null) _goto(next);
  }

  void _goto(VideoRef v) {
    setState(() => _related = []);
    _open(v);
  }

  Future<void> _loadRelated() async {
    if (_relatedLoading) return;
    setState(() => _relatedLoading = true);
    try {
      final p = await Yt.search(_video.title);
      final id = _video.id;
      final l = p.items.where((e) => e.id != id).toList();
      if (mounted) setState(() => _related = l);
    } catch (_) {}
    if (mounted) setState(() => _relatedLoading = false);
  }

  // --------------------------------------------- leaving / returning to app

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _life = s;
    _leaveT?.cancel();
    if (s == AppLifecycleState.resumed) {
      _onForeground();
    } else if (s == AppLifecycleState.inactive) {
      // Early trigger: starting the audio service while the app is still
      // (barely) in the foreground is more reliable on new Android versions.
      _leaveT = Timer(const Duration(milliseconds: 700), _onBackground);
    } else {
      _onBackground();
    }
  }

  void _pipChanged() {
    if (!Pip.inPip.value && _life != AppLifecycleState.resumed) _onBackground();
  }

  Future<void> _onBackground() async {
    if (_life == AppLifecycleState.resumed || Pip.inPip.value) return;
    final c = _vc;
    if (c == null || _bg || _audioMode) return;
    if (!c.value.isPlaying) return;
    if (Settings.I.leaveMode == LeaveMode.stop) {
      await c.pause();
      return;
    }
    final pos = c.value.position;
    _bg = true; // video is released, audio takes over (saves data + battery)
    await _open(_video, start: pos);
  }

  Future<void> _onForeground() async {
    if (!_bg) return;
    final pos = audioHandler.position;
    final was = audioHandler.playing;
    _bg = false;
    await _open(_video, start: pos, autoplay: was);
  }

  // ---------------------------------------------------------------- controls

  void _poke() {
    _hideT?.cancel();
    if (!_controls && mounted) setState(() => _controls = true);
    _hideT = Timer(const Duration(seconds: 3), () {
      if (mounted && !(_audioMode || _bg)) setState(() => _controls = false);
    });
  }

  void _tap() {
    if (_controls) {
      setState(() => _controls = false);
    } else {
      _poke();
    }
  }

  void _playPause() {
    _poke();
    if (_audioMode || _bg) {
      audioHandler.playing ? audioHandler.pause() : unawaited(audioHandler.play());
    } else {
      final c = _vc;
      if (c == null) return;
      c.value.isPlaying ? c.pause() : c.play();
    }
  }

  void _seekTo(Duration d) {
    _poke();
    final audio = _audioMode || _bg;
    final total = audio ? audioHandler.duration : (_vc?.value.duration ?? Duration.zero);
    if (d < Duration.zero) d = Duration.zero;
    if (total > Duration.zero && d > total) d = total;
    if (audio) {
      audioHandler.seek(d);
    } else {
      _vc?.seekTo(d);
    }
  }

  void _toggleAudio() {
    final pos = _pos();
    setState(() => _audioMode = !_audioMode);
    _open(_video, start: pos);
  }

  void _changeQuality(int h) {
    final pos = _pos();
    _height = h;
    _open(_video, start: pos);
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    SystemChrome.setPreferredOrientations(
        _full ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(_full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  Future<void> _openChannel() async {
    final v = await Navigator.of(context).push<VideoRef>(MaterialPageRoute(
        builder: (_) => ChannelScreen(channelId: _video.channelId, name: _video.author)));
    if (v != null && mounted) _goto(v);
  }

  // ---------------------------------------------------------------------- UI

  Widget _surface() {
    if (_audioMode || _bg) {
      return CachedNetworkImage(
        imageUrl: _video.thumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => const SizedBox.expand(),
      );
    }
    final c = _vc;
    if (c != null && c.value.isInitialized) {
      return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)));
    }
    return const SizedBox.expand();
  }

  Widget _bar({required Duration pos, required Duration dur, required bool playing, required bool buffering}) {
    final audio = _audioMode || _bg;
    final qualities = _muxed.map((m) => m.videoResolution.height).toSet().toList()..sort();
    return _ControlBar(
      pos: pos,
      dur: dur,
      playing: playing,
      buffering: buffering,
      audio: audio,
      full: _full,
      qualities: qualities,
      quality: _muxed.isEmpty ? 0 : _pick().videoResolution.height,
      onBack: () => Navigator.of(context).maybePop(),
      onPlayPause: _playPause,
      onSeek: _seekTo,
      onFull: _toggleFull,
      onPip: () {
        _poke();
        Pip.enter();
      },
      onAudio: _toggleAudio,
      onQuality: _changeQuality,
    );
  }

  Widget _controlsLayer() {
    if (_audioMode || _bg) {
      return StreamBuilder<PlaybackState>(
        stream: audioHandler.playbackState,
        builder: (_, st) => StreamBuilder<Duration>(
          stream: AudioService.position,
          builder: (_, p) => _bar(
            pos: p.data ?? Duration.zero,
            dur: audioHandler.duration,
            playing: st.data?.playing ?? false,
            buffering: st.data?.processingState == AudioProcessingState.buffering ||
                st.data?.processingState == AudioProcessingState.loading,
          ),
        ),
      );
    }
    final c = _vc;
    if (c == null) return const SizedBox();
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (_, v, __) =>
          _bar(pos: v.position, dur: v.duration, playing: v.isPlaying, buffering: v.isBuffering),
    );
  }

  Widget _player() {
    final audio = _audioMode || _bg;
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        _surface(),
        if (audio) Container(color: Colors.black54),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(S.t('error'), style: const TextStyle(color: Colors.white)),
              TextButton(onPressed: () => _open(_video, start: _pos()), child: Text(S.t('retry'))),
            ]),
          ),
        GestureDetector(behavior: HitTestBehavior.translucent, onTap: _tap),
        if ((_controls || audio) && !_loading && _error == null) _controlsLayer(),
      ]),
    );
  }

  Widget _details() {
    final v = _video;
    final th = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.title, style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(v.subtitle(author: false),
            style: th.textTheme.bodySmall?.copyWith(color: th.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ActionChip(
            avatar: const Icon(Icons.account_circle_outlined, size: 18),
            label: Text(v.author),
            onPressed: _openChannel,
          ),
          ListenableBuilder(
            listenable: Store.I,
            builder: (_, __) => ActionChip(
              avatar: Icon(Store.I.isSaved(v.id) ? Icons.bookmark : Icons.bookmark_border, size: 18),
              label: Text(S.t('save')),
              onPressed: () => Store.I.toggleSaved(v),
            ),
          ),
          ListenableBuilder(
            listenable: Downloads.I,
            builder: (_, __) {
              final d = Downloads.I;
              final busy = d.active(v.id);
              return ActionChip(
                avatar: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, value: d.progress[v.id]))
                    : Icon(d.has(v.id) ? Icons.download_done : Icons.download, size: 18),
                label: Text(busy
                    ? '${((d.progress[v.id] ?? 0) * 100).round()}%'
                    : S.t(d.has(v.id) ? 'downloaded' : 'download')),
                onPressed: () {
                  if (busy) {
                    d.cancel(v.id);
                  } else if (d.has(v.id)) {
                    d.remove(v.id);
                  } else {
                    d.start(v);
                  }
                },
              );
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.link, size: 18),
            label: Text(S.t('copyLink')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://youtu.be/${v.id}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('copied'))));
            },
          ),
        ]),
      ]),
    );
  }

  Widget _body() {
    return ListView.builder(
      itemCount: 2 + _related.length,
      itemBuilder: (ctx, i) {
        if (i == 0) return _details();
        if (i == 1) {
          if (_related.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(S.t('related'), style: Theme.of(ctx).textTheme.titleSmall),
            );
          }
          if (_relatedLoading) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _loadRelated,
              icon: const Icon(Icons.expand_more),
              label: Text(S.t('loadRelated')),
            ),
          );
        }
        final v = _related[i - 2];
        return VideoTile(key: ValueKey(v.id), v: v, compact: true, onTap: () => _goto(v));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Pip.inPip,
      builder: (context, pip, _) {
        if (pip) return Scaffold(backgroundColor: Colors.black, body: _surface());
        return PopScope(
          canPop: !_full,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _toggleFull();
          },
          child: Scaffold(
            body: _full
                ? _player()
                : SafeArea(
                    child: Column(children: [
                      AspectRatio(aspectRatio: 16 / 9, child: _player()),
                      Expanded(child: _body()),
                    ]),
                  ),
          ),
        );
      },
    );
  }
}

class _ControlBar extends StatefulWidget {
  final Duration pos, dur;
  final bool playing, buffering, audio, full;
  final List<int> qualities;
  final int quality;
  final VoidCallback onBack, onPlayPause, onFull, onPip, onAudio;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<int> onQuality;

  const _ControlBar({
    required this.pos,
    required this.dur,
    required this.playing,
    required this.buffering,
    required this.audio,
    required this.full,
    required this.qualities,
    required this.quality,
    required this.onBack,
    required this.onPlayPause,
    required this.onFull,
    required this.onPip,
    required this.onAudio,
    required this.onSeek,
    required this.onQuality,
  });

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final maxMs = widget.dur.inMilliseconds < 1 ? 1.0 : widget.dur.inMilliseconds.toDouble();
    final val = (_drag ?? widget.pos.inMilliseconds.toDouble()).clamp(0.0, maxMs).toDouble();
    return Container(
      color: Colors.black45,
      child: Column(children: [
        Row(children: [
          IconButton(
            icon: Icon(widget.full ? Icons.arrow_back : Icons.keyboard_arrow_down, color: white),
            onPressed: widget.onBack,
          ),
          const Spacer(),
          IconButton(
            tooltip: S.t(widget.audio ? 'watchVideo' : 'listenOnly'),
            icon: Icon(widget.audio ? Icons.videocam : Icons.headphones, color: white),
            onPressed: widget.onAudio,
          ),
          if (!widget.audio && Pip.supported)
            IconButton(
              tooltip: S.t('floating'),
              icon: const Icon(Icons.picture_in_picture_alt, color: white),
              onPressed: widget.onPip,
            ),
          if (!widget.audio && widget.qualities.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.settings, color: white),
              initialValue: widget.quality,
              onSelected: widget.onQuality,
              itemBuilder: (_) => [for (final q in widget.qualities) PopupMenuItem(value: q, child: Text('${q}p'))],
            ),
        ]),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.replay_10, color: white),
              onPressed: () => widget.onSeek(widget.pos - const Duration(seconds: 10)),
            ),
            const SizedBox(width: 12),
            widget.buffering
                ? const SizedBox(
                    width: 56,
                    height: 56,
                    child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: white)),
                  )
                : IconButton(
                    iconSize: 56,
                    icon: Icon(widget.playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: white),
                    onPressed: widget.onPlayPause,
                  ),
            const SizedBox(width: 12),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.forward_10, color: white),
              onPressed: () => widget.onSeek(widget.pos + const Duration(seconds: 10)),
            ),
          ]),
        ),
        Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(fmtDuration(widget.pos), style: const TextStyle(color: white, fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: val,
                max: maxMs,
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  widget.onSeek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
            ),
          ),
          Text(fmtDuration(widget.dur), style: const TextStyle(color: white, fontSize: 12)),
          if (!widget.audio)
            IconButton(
              icon: Icon(widget.full ? Icons.fullscreen_exit : Icons.fullscreen, color: white),
              onPressed: widget.onFull,
            )
          else
            const SizedBox(width: 12),
        ]),
      ]),
    );
  }
}
