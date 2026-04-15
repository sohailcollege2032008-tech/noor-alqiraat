import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/download_service.dart';
import 'data_providers.dart';

final downloadServiceProvider = Provider((ref) => DownloadService());

/// Tracks active download progress.
/// Key: fileKey (e.g. "hafs_001.mp3"), Value: 0.0–1.0
/// A key is absent when not downloading.
class DownloadProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void _set(String key, double progress) {
    state = {...state, key: progress};
  }

  void _remove(String key) {
    final next = Map<String, double>.from(state);
    next.remove(key);
    state = next;
  }

  Future<void> download({
    required DownloadService service,
    required String category,
    required String audioFile,
    required String url,
  }) async {
    final key = service.fileKey(category, audioFile);
    _set(key, 0.0);
    try {
      await service.downloadFile(
        category: category,
        audioFile: audioFile,
        url: url,
        onProgress: (p) => _set(key, p),
      );
    } finally {
      _remove(key);
    }
  }
}

final downloadProgressProvider =
    NotifierProvider<DownloadProgressNotifier, Map<String, double>>(
        DownloadProgressNotifier.new);

/// Triggers a download with the correct R2 URL resolved automatically.
final downloadItemProvider = Provider((ref) {
  return (String category, String audioFile) async {
    final service = ref.read(downloadServiceProvider);
    final baseUrl = await ref.read(activeBaseUrlProvider.future);
    final url = '$baseUrl/$category/$audioFile';
    await ref.read(downloadProgressProvider.notifier).download(
          service: service,
          category: category,
          audioFile: audioFile,
          url: url,
        );
  };
});
