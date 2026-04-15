import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/audio_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(audioPlaybackStateProvider);
    final positionAsync = ref.watch(audioPositionProvider);

    if (!mediaItemAsync.hasValue || mediaItemAsync.value == null) {
      return const SizedBox.shrink();
    }

    final mediaItem = mediaItemAsync.value!;
    final playbackState = playbackStateAsync.value;
    final isPlaying = playbackState?.playing ?? false;
    final position = positionAsync.value ?? Duration.zero;
    final duration = ref.watch(audioDurationProvider).value ?? mediaItem.duration ?? Duration.zero;

    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = position.inMilliseconds / duration.inMilliseconds;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const FullPlayerModal(),
        );
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(0, -2), blurRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // Progress bar is always LTR (fills left→right regardless of app locale)
            Directionality(
              textDirection: TextDirection.ltr,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.secondary),
                minHeight: 3,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mediaItem.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            mediaItem.album ?? '',
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 36,
                      ),
                      onPressed: () async {
                        final handler =
                            await ref.read(audioHandlerProvider.future);
                        if (isPlaying) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullPlayerModal extends ConsumerWidget {
  const FullPlayerModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(audioPlaybackStateProvider);
    final positionAsync = ref.watch(audioPositionProvider);
    final handlerAsync = ref.watch(audioHandlerProvider);

    if (!mediaItemAsync.hasValue || mediaItemAsync.value == null) {
      return const SizedBox.shrink();
    }

    final mediaItem = mediaItemAsync.value!;
    final playbackState = playbackStateAsync.value;
    final isPlaying = playbackState?.playing ?? false;
    final isBuffering =
        playbackState?.processingState == AudioProcessingState.buffering ||
            playbackState?.processingState == AudioProcessingState.loading;
    final position = positionAsync.value ?? Duration.zero;

    // Use live duration stream; fall back to mediaItem.duration only if stream
    // hasn't emitted yet. Never use a hardcoded fallback like Duration(minutes:5).
    final liveDuration = ref.watch(audioDurationProvider).value;
    final duration = liveDuration ?? mediaItem.duration ?? Duration.zero;
    final isDurationReady = duration.inMilliseconds > 0;

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note, size: 100, color: Colors.white),
          ),

          const SizedBox(height: 32),
          Text(mediaItem.title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(mediaItem.album ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey)),

          const SizedBox(height: 32),

          // Slider — always LTR so left=start, right=end regardless of app locale
          Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Slider(
                    value: isDurationReady
                        ? position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, duration.inMilliseconds.toDouble())
                        : 0.0,
                    min: 0.0,
                    max: isDurationReady
                        ? duration.inMilliseconds.toDouble()
                        : 1.0,
                    activeColor: Theme.of(context).colorScheme.secondary,
                    onChanged: isDurationReady
                        ? (value) async {
                            if (handlerAsync.hasValue) {
                              handlerAsync.value!
                                  .seek(Duration(milliseconds: value.toInt()));
                            }
                          }
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position),
                          style: const TextStyle(fontFamily: 'Roboto')),
                      isDurationReady
                          ? Text(formatDuration(duration),
                              style: const TextStyle(fontFamily: 'Roboto'))
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Media controls — LTR so rewind is always on the left
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 36),
                  onPressed: () async {
                    if (handlerAsync.hasValue) {
                      handlerAsync.value!
                          .seek(position - const Duration(seconds: 10));
                    }
                  },
                ),
                const SizedBox(width: 20),
                isBuffering
                    ? const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator())
                    : IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Theme.of(context).primaryColor,
                          size: 64,
                        ),
                        onPressed: () async {
                          if (handlerAsync.hasValue) {
                            if (isPlaying) {
                              handlerAsync.value!.pause();
                            } else {
                              handlerAsync.value!.play();
                            }
                          }
                        },
                      ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 36),
                  onPressed: () async {
                    if (handlerAsync.hasValue) {
                      handlerAsync.value!
                          .seek(position + const Duration(seconds: 10));
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Speed & A-B controls
          Builder(builder: (context) {
            final speed = playbackState?.speed ?? 1.0;
            final markerA = handlerAsync.value?.markerA;
            final markerB = handlerAsync.value?.markerB;
            final isABEnabled =
                handlerAsync.value?.isABRepeatEnabled ?? false;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    if (handlerAsync.hasValue) {
                      const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                      final closest = speeds.reduce((a, b) =>
                          (speed - a).abs() < (speed - b).abs() ? a : b);
                      int idx = speeds.indexOf(closest);
                      if (idx == speeds.length - 1) idx = -1;
                      await handlerAsync.value!.setSpeed(speeds[idx + 1]);
                    }
                  },
                  icon:
                      Icon(Icons.speed, color: Theme.of(context).primaryColor),
                  label: Text('${speed}x',
                      style:
                          TextStyle(color: Theme.of(context).primaryColor)),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isABEnabled
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: isABEnabled
                        ? Theme.of(context)
                            .colorScheme
                            .secondary
                            .withAlpha(25)
                        : Colors.transparent,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          if (handlerAsync.hasValue) {
                            handlerAsync.value!.setABMarkerA(position);
                          }
                        },
                        child: Text(
                          markerA != null ? 'A' : 'Set A',
                          style: TextStyle(
                              color: markerA != null
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey),
                        ),
                      ),
                      const Text('-', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () {
                          if (handlerAsync.hasValue) {
                            handlerAsync.value!.setABMarkerB(position);
                          }
                        },
                        child: Text(
                          markerB != null ? 'B' : 'Set B',
                          style: TextStyle(
                              color: markerB != null
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey),
                        ),
                      ),
                      if (markerA != null || markerB != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (handlerAsync.hasValue) {
                              handlerAsync.value!.clearABMarkers();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
