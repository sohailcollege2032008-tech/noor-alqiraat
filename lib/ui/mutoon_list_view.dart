import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/data_providers.dart';
import '../providers/audio_providers.dart';
import '../providers/download_providers.dart';
import 'download_button.dart';

// Level 1 — list of Mutoon
class MutoonListView extends ConsumerWidget {
  const MutoonListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutoonDataAsync = ref.watch(mutoonIndexProvider);

    return mutoonDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (mutoonList) {
        if (mutoonList.isEmpty) {
          return const Center(child: Text('لا توجد متون'));
        }
        return ListView.builder(
          itemCount: mutoonList.length,
          itemBuilder: (context, index) {
            final matn = mutoonList[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                matn.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${matn.chapters.length} باب'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatnChaptersScreen(matn: matn),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Level 2 — chapters of a selected Matn
class MatnChaptersScreen extends ConsumerWidget {
  final Mutoon matn;

  const MatnChaptersScreen({Key? key, required this.matn}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(matn.name),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: matn.chapters.length,
        itemBuilder: (context, index) {
          final chapter = matn.chapters[index];
          final relativeAudioPath = '${matn.folder}/${chapter.audioFile}';

          return Consumer(
            builder: (context, ref, child) {
              final availabilityAsync =
                  ref.watch(fileAvailabilityProvider(relativeAudioPath));

              return availabilityAsync.when(
                loading: () => const ListTile(
                  title: Text('...'),
                  trailing: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, st) => ListTile(
                  leading: const Icon(Icons.library_music, color: Colors.grey),
                  title: Text(chapter.name,
                      style: const TextStyle(color: Colors.grey)),
                  trailing: const Text('قريباً',
                      style: TextStyle(color: Colors.grey)),
                ),
                data: (isAvailable) {
                  if (!isAvailable) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Text('${chapter.id}',
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      title: Text(chapter.name,
                          style: const TextStyle(color: Colors.grey)),
                      trailing: const Text('قريباً',
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    );
                  }
                  return _AvailableChapterTile(
                    chapter: chapter,
                    folder: matn.folder,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Level 3 — tile that triggers playback
class _AvailableChapterTile extends ConsumerWidget {
  final MutoonChapter chapter;
  final String folder;

  const _AvailableChapterTile({
    required this.chapter,
    required this.folder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadService = ref.watch(downloadServiceProvider);
    final progressMap = ref.watch(downloadProgressProvider);
    final fileKey = downloadService.fileKey(folder, chapter.audioFile);
    final activeProgress = progressMap[fileKey];
    final isDownloaded = downloadService.isDownloaded(folder, chapter.audioFile);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child:
            Text('${chapter.id}', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(chapter.name,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DownloadButton(
            isDownloaded: isDownloaded,
            activeProgress: activeProgress,
            onDownload: () =>
                ref.read(downloadItemProvider)(folder, chapter.audioFile),
            onDelete: () =>
                downloadService.deleteFile(folder, chapter.audioFile),
          ),
          const SizedBox(width: 4),
          Icon(Icons.play_circle_fill,
              color: Theme.of(context).colorScheme.secondary),
        ],
      ),
      onTap: () => ref.read(playItemProvider)(
          folder, 'matn_${chapter.id}', chapter.name, chapter.audioFile),
    );
  }
}
