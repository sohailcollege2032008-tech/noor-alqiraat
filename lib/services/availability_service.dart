import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AvailabilityService {
  final Dio _dio = Dio();
  final Box _cacheBox = Hive.box('availabilityCache');

  // Cache validity: 24 hours to match aggressive caching requirement
  final Duration _cacheDuration = const Duration(hours: 24);

  Future<bool> checkFileExists(String url) async {
    // 1. Check aggressively in cache
    final cachedData = _cacheBox.get(url);
    if (cachedData != null) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
      final isAvailable = cachedData['isAvailable'] as bool;
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        debugPrint('AvailabilityService [CACHE HIT]: $url -> $isAvailable');
        return isAvailable;
      }
    }

    // 2. Perform lightweight GET with Range header (CORS-safe, works on web with R2)
    //    R2 returns 206 for existing files, 404 for missing ones.
    debugPrint('AvailabilityService [GET RANGE REQUEST]: $url');
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Range': 'bytes=0-0'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final statusCode = response.statusCode ?? 0;
      debugPrint('AvailabilityService [RESPONSE]: $url -> $statusCode');
      // 200 (full) or 206 (partial) both mean the file exists
      final isAvailable = statusCode == 200 || statusCode == 206;

      // Only cache definitive server responses
      await _cacheBox.put(url, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAvailable': isAvailable,
      });
      return isAvailable;
    } catch (e) {
      // Network/CORS/timeout error — do NOT cache, fall back to stale cache if available
      debugPrint('AvailabilityService [NETWORK ERROR]: $url -> $e');
      if (cachedData != null) {
        debugPrint('AvailabilityService [STALE CACHE]: returning cached value for $url');
        return cachedData['isAvailable'] as bool;
      }
      return false;
    }
  }
}
