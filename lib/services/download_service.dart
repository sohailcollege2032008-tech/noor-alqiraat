import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();
  final Box _box = Hive.box('downloaded_files');

  /// Canonical key used for Hive tracking and file naming.
  /// e.g. category=hafs, audioFile=001.mp3 → "hafs_001.mp3"
  String fileKey(String category, String audioFile) => '${category}_$audioFile';

  Future<String> _localFilePath(String category, String audioFile) async {
    final dir = await getApplicationDocumentsDirectory(); // not available on web — guard at UI layer
    return '${dir.path}/${fileKey(category, audioFile)}';
  }

  bool isDownloaded(String category, String audioFile) {
    return _box.get(fileKey(category, audioFile), defaultValue: false) as bool;
  }

  Future<String?> getLocalPath(String category, String audioFile) async {
    if (!isDownloaded(category, audioFile)) return null;
    final path = await _localFilePath(category, audioFile);
    // Verify the file actually exists (guard against manual deletion)
    if (File(path).existsSync()) return path;
    // File was deleted externally — clean up the Hive entry
    await _box.delete(fileKey(category, audioFile));
    return null;
  }

  /// Downloads [url] to local storage, calling [onProgress] with 0.0–1.0.
  /// Returns the local file path on success.
  Future<String> downloadFile({
    required String category,
    required String audioFile,
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    final path = await _localFilePath(category, audioFile);
    debugPrint('DownloadService [START]: $url → $path');

    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    await _box.put(fileKey(category, audioFile), true);
    debugPrint('DownloadService [DONE]: $path');
    return path;
  }

  Future<void> deleteFile(String category, String audioFile) async {
    final path = await _localFilePath(category, audioFile);
    final file = File(path);
    if (file.existsSync()) await file.delete();
    await _box.delete(fileKey(category, audioFile));
    debugPrint('DownloadService [DELETED]: $path');
  }
}
