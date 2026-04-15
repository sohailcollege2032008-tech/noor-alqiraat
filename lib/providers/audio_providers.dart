import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../services/user_prefs_service.dart';
import '../services/download_service.dart';
import 'data_providers.dart';

// Global singleton state — survives hot restarts within the same process
AppAudioHandler? _audioHandlerInstance;
bool _isAudioServiceInitialized = false;

Future<AppAudioHandler> initAudioService() async {
  // Return existing instance immediately — never call AudioService.init twice
  if (_isAudioServiceInitialized && _audioHandlerInstance != null) {
    return _audioHandlerInstance!;
  }

  try {
    final handler = await AudioService.init(
      builder: () => AppAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sohaib.noor_alqiraat.channel.audio',
        androidNotificationChannelName: 'Noor Al-Qira\'at Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    _audioHandlerInstance = handler as AppAudioHandler;
    _isAudioServiceInitialized = true;
  } catch (e) {
    // AudioService.init threw — service was already initialized (e.g. hot restart).
    // If we already have an instance from before the restart, reuse it.
    if (_audioHandlerInstance != null) {
      _isAudioServiceInitialized = true;
      return _audioHandlerInstance!;
    }
    // No instance at all — rethrow so the UI shows a meaningful error.
    rethrow;
  }

  return _audioHandlerInstance!;
}

final audioHandlerProvider = FutureProvider<AppAudioHandler>((ref) async {
  final handler = await initAudioService();

  // Auto-Resume — only runs on first real initialization
  final lastTrack = UserPrefsService().getLastTrack();
  if (lastTrack != null) {
    try {
      final category = lastTrack['last_category'] as String;
      final audioFile = lastTrack['last_audio_file'] as String;
      final item = MediaItem(
        id: lastTrack['last_item_id'],
        title: lastTrack['last_name'],
        album: category,
      );
      final position = Duration(milliseconds: lastTrack['last_position_ms'] as int);
      final speed = lastTrack['last_speed'] as double;

      final localPath = kIsWeb ? null : await DownloadService().getLocalPath(category, audioFile);
      if (localPath != null) {
        await handler.prepareFile(item, localPath, position, speed);
      } else {
        final baseUrl = await ref.read(activeBaseUrlProvider.future);
        await handler.prepareUrl(item, '$baseUrl/$category/$audioFile', position, speed);
      }
    } catch (_) {
      // Auto-resume is best-effort — never block startup
    }
  }

  return handler;
});

final audioPositionProvider = StreamProvider<Duration>((ref) async* {
  final handler = await ref.watch(audioHandlerProvider.future);
  yield* handler.positionStream;
});

final audioBufferedPositionProvider = StreamProvider<Duration>((ref) async* {
  final handler = await ref.watch(audioHandlerProvider.future);
  yield* handler.bufferedPositionStream;
});

final audioDurationProvider = StreamProvider<Duration?>((ref) async* {
  final handler = await ref.watch(audioHandlerProvider.future);
  yield* handler.durationStream;
});

final audioPlaybackStateProvider = StreamProvider<PlaybackState>((ref) async* {
  final handler = await ref.watch(audioHandlerProvider.future);
  yield* handler.playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) async* {
  final handler = await ref.watch(audioHandlerProvider.future);
  yield* handler.mediaItem;
});

// Provider to trigger playback — checks local file first, falls back to streaming
final playItemProvider = Provider((ref) {
  return (String category, String id, String name, String audioFile) async {
    final handler = await ref.read(audioHandlerProvider.future);

    UserPrefsService().saveCurrentTrack(category: category, itemId: id, name: name, audioFile: audioFile);

    final item = MediaItem(id: id, title: name, album: category);

    final localPath = kIsWeb ? null : await DownloadService().getLocalPath(category, audioFile);
    if (localPath != null) {
      await handler.playFile(item, localPath);
    } else {
      final baseUrl = await ref.read(activeBaseUrlProvider.future);
      await handler.playUrl(item, '$baseUrl/$category/$audioFile');
    }
  };
});
