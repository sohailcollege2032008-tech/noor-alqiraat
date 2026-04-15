import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../providers/audio_providers.dart';
import '../providers/download_providers.dart';
import 'download_button.dart';

// Available riwayat — extend this list as more are uploaded
const _riwayat = [
  ('hafs', 'حفص عن عاصم'),
  ('warsh', 'ورش عن نافع'),
  ('qalun', 'قالون عن نافع'),
  ('al_duri_abi_amr', 'الدوري عن أبي عمرو'),
];

class QuranListView extends ConsumerWidget {
  const QuranListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quranDataAsync = ref.watch(quranIndexProvider);
    final selectedRiwayah = ref.watch(selectedRiwayahProvider);

    final riwayahLabel = _riwayat
        .firstWhere((r) => r.$1 == selectedRiwayah,
            orElse: () => (selectedRiwayah, selectedRiwayah))
        .$2;

    return Column(
      children: [
        // Riwayah selector bar
        InkWell(
          onTap: () => _showRiwayahSelector(context, ref, selectedRiwayah),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(20),
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).primaryColor.withAlpha(60)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book,
                    color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'الرواية: $riwayahLabel',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(Icons.swap_horiz,
                    color: Theme.of(context).primaryColor, size: 20),
              ],
            ),
          ),
        ),

        // Surah list
        Expanded(
          child: quranDataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (surahs) {
              return ListView.builder(
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  final relativeAudioPath =
                      '$selectedRiwayah/${surah.audioFile}';

                  return Consumer(
                    builder: (context, ref, child) {
                      final availabilityAsync = ref
                          .watch(fileAvailabilityProvider(relativeAudioPath));

                      return availabilityAsync.when(
                        loading: () => const ListTile(
                          title: Text('...'),
                          trailing: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (e, st) => ListTile(
                          title: Text(surah.name,
                              style: const TextStyle(color: Colors.grey)),
                          leading:
                              CircleAvatar(child: Text('${surah.id}')),
                          trailing: const Text('قريباً',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        data: (isAvailable) {
                          if (!isAvailable) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: Text('${surah.id}',
                                    style: const TextStyle(
                                        color: Colors.grey)),
                              ),
                              title: Text(surah.name,
                                  style:
                                      const TextStyle(color: Colors.grey)),
                              trailing: const Text('قريباً',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                              onTap: null,
                            );
                          }
                          return _AvailableSurahTile(
                            surahId: surah.id,
                            surahName: surah.name,
                            category: selectedRiwayah,
                            audioFile: surah.audioFile,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRiwayahSelector(
      BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر الرواية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ..._riwayat.map((r) {
                final isSelected = r.$1 == current;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                  title: Text(
                    r.$2,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  onTap: () {
                    if (r.$1 != current) {
                      // Update selection
                      ref
                          .read(selectedRiwayahProvider.notifier)
                          .setRiwayah(r.$1);
                      // Invalidate all availability checks so they re-fetch
                      // for the new riwayah's URLs
                      ref.invalidate(fileAvailabilityProvider);
                    }
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _AvailableSurahTile extends ConsumerWidget {
  final int surahId;
  final String surahName;
  final String category;
  final String audioFile;

  const _AvailableSurahTile({
    required this.surahId,
    required this.surahName,
    required this.category,
    required this.audioFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadService = ref.watch(downloadServiceProvider);
    final progressMap = ref.watch(downloadProgressProvider);
    final fileKey = downloadService.fileKey(category, audioFile);
    final activeProgress = progressMap[fileKey];
    final isDownloaded = downloadService.isDownloaded(category, audioFile);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child:
            Text('$surahId', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(surahName,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DownloadButton(
            isDownloaded: isDownloaded,
            activeProgress: activeProgress,
            onDownload: () =>
                ref.read(downloadItemProvider)(category, audioFile),
            onDelete: () => downloadService.deleteFile(category, audioFile),
          ),
          const SizedBox(width: 4),
          Icon(Icons.play_circle_fill,
              color: Theme.of(context).colorScheme.secondary),
        ],
      ),
      onTap: () => ref
          .read(playItemProvider)(category, 'surah_$surahId', surahName, audioFile),
    );
  }
}
