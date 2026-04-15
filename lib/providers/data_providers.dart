import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/remote_config_service.dart';
import '../services/availability_service.dart';

final remoteConfigServiceProvider = Provider((ref) => RemoteConfigService());
final availabilityServiceProvider = Provider((ref) => AvailabilityService());

final fileAvailabilityProvider = FutureProvider.family<bool, String>((ref, relativeAudioPath) async {
  final baseUrl = await ref.read(activeBaseUrlProvider.future);
  final fullUrl = '$baseUrl/$relativeAudioPath';
  debugPrint('fileAvailabilityProvider [URL BUILT]: $fullUrl');
  return ref.watch(availabilityServiceProvider).checkFileExists(fullUrl);
});

final activeBaseUrlProvider = FutureProvider<String>((ref) async {
  final service = ref.read(remoteConfigServiceProvider);
  final url = await service.fetchActiveBaseUrl();
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
});

final quranIndexProvider = FutureProvider<List<Surah>>((ref) async {
  final String response = await rootBundle.loadString('assets/data/quran_index.json');
  final List<dynamic> data = json.decode(response);
  return data.map((json) => Surah.fromJson(json)).toList();
});

final mutoonIndexProvider = FutureProvider<List<Mutoon>>((ref) async {
  final String response = await rootBundle.loadString('assets/data/mutoon_index.json');
  final List<dynamic> data = json.decode(response);
  return data.map((json) => Mutoon.fromJson(json)).toList();
});

class RiwayahNotifier extends Notifier<String> {
  @override
  String build() => 'hafs';

  void setRiwayah(String riwayah) => state = riwayah;
}

final selectedRiwayahProvider = NotifierProvider<RiwayahNotifier, String>(RiwayahNotifier.new);
