import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'user_prefs_service.dart';

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // A-B Repeat State
  Duration? markerA;
  Duration? markerB;
  bool isABRepeatEnabled = false;

  AppAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    
    int _lastSavedMs = 0;
    // Listen to position for A-B repeat logic & persistence
    _player.positionStream.listen((position) {
      if (isABRepeatEnabled && markerB != null && markerA != null) {
        if (position >= markerB!) {
          _player.seek(markerA!);
        }
      }

      // Throttle exact progress writes to ~every 5 seconds
      if ((position.inMilliseconds - _lastSavedMs).abs() > 5000) {
        _lastSavedMs = position.inMilliseconds;
        UserPrefsService().savePosition(position);
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
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
      queueIndex: event.currentIndex,
    ));
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
    return super.stop();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    await UserPrefsService().saveSpeed(speed);
  }

  Future<void> playUrl(MediaItem item, String url) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    await _player.play();
  }

  /// Plays from a local file path (offline mode).
  Future<void> playFile(MediaItem item, String filePath) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.file(filePath));
    await _player.play();
  }

  Future<void> prepareUrl(MediaItem item, String url, Duration startPosition, double speed) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url)), initialPosition: startPosition);
    await _player.setSpeed(speed);
    // Does not trigger play(), leaves the player paused in ready state for auto-resume
  }

  /// Prepares from a local file path (offline auto-resume).
  Future<void> prepareFile(MediaItem item, String filePath, Duration startPosition, double speed) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.file(filePath), initialPosition: startPosition);
    await _player.setSpeed(speed);
  }

  // Custom A-B repeat methods
  void setABMarkerA(Duration position) {
    markerA = position;
    _checkABEnabled();
  }

  void setABMarkerB(Duration position) {
    markerB = position;
    _checkABEnabled();
  }

  void clearABMarkers() {
    markerA = null;
    markerB = null;
    isABRepeatEnabled = false;
  }

  void _checkABEnabled() {
    if (markerA != null && markerB != null && markerB! > markerA!) {
      isABRepeatEnabled = true;
    } else {
      isABRepeatEnabled = false;
    }
  }

  // Getters for UI to observe properties directly if needed
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  double get currentSpeed => _player.speed;
}
