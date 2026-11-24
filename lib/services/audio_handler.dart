import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

late PenAudioHandler audioHandler;

/// Audio-only playback: keeps going with the screen off / app closed,
/// with lock-screen + notification controls.
class PenAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  void Function()? onCompleted;

  PenAudioHandler() {
    _player.playbackEventStream.listen(_broadcast, onError: (_) {});
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) onCompleted?.call();
    });
  }

  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? mediaItem.value?.duration ?? Duration.zero;

  Future<void> load(String url, MediaItem item, {Duration start = Duration.zero}) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(url.startsWith('/') ? Uri.file(url) : Uri.parse(url)), initialPosition: start);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcast(PlaybackEvent e) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    ));
  }
}
