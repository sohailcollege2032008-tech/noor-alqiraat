import 'package:hive_flutter/hive_flutter.dart';

class UserPrefsService {
  final Box _prefsBox = Hive.box('user_prefs');

  // Singletons pattern for easy access within handlers
  static final UserPrefsService _instance = UserPrefsService._internal();
  factory UserPrefsService() => _instance;
  UserPrefsService._internal();

  /// Saves the core metadata for the current track so it can be reconstructed completely
  Future<void> saveCurrentTrack({
    required String category,
    required String itemId,
    required String name,
    required String audioFile,
  }) async {
    await _prefsBox.put('last_category', category);
    await _prefsBox.put('last_item_id', itemId);
    await _prefsBox.put('last_name', name);
    await _prefsBox.put('last_audio_file', audioFile);
  }

  Future<void> savePosition(Duration position) async {
    await _prefsBox.put('last_position_ms', position.inMilliseconds);
  }

  Future<void> saveSpeed(double speed) async {
    await _prefsBox.put('last_speed', speed);
  }

  Map<String, dynamic>? getLastTrack() {
    final itemId = _prefsBox.get('last_item_id');
    if (itemId != null) {
      return {
        'last_category': _prefsBox.get('last_category'),
        'last_item_id': itemId,
        'last_name': _prefsBox.get('last_name'),
        'last_audio_file': _prefsBox.get('last_audio_file'),
        'last_position_ms': _prefsBox.get('last_position_ms', defaultValue: 0),
        'last_speed': _prefsBox.get('last_speed', defaultValue: 1.0),
      };
    }
    return null;
  }
}
