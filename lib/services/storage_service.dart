import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyBaseUrl = 'app_api_base_url';
  static const String _keySelectedProfileId = 'app_selected_profile_id';
  static const String _keySelectedBoxId = 'app_selected_box_id';
  static const String _keyThemeMode = 'app_theme_mode';

  SharedPreferences? _prefs;
  bool _initAttempted = false;
  final Map<String, Object> _inMemoryFallback = {};

  StorageService([this._prefs]);

  static Future<StorageService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StorageService(prefs);
    } catch (_) {
      return StorageService();
    }
  }

  Future<SharedPreferences?> _getSafePrefs() async {
    if (_prefs != null) return _prefs;
    if (_initAttempted) return null;
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 50),
      );
      return _prefs;
    } catch (_) {
      _initAttempted = true;
      return null;
    }
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setString(_keyBaseUrl, url);
    } else {
      _inMemoryFallback[_keyBaseUrl] = url;
    }
  }

  Future<String?> getBaseUrl() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getString(_keyBaseUrl);
    }
    return _inMemoryFallback[_keyBaseUrl] as String?;
  }

  Future<void> saveSelectedProfileId(int id) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setInt(_keySelectedProfileId, id);
    } else {
      _inMemoryFallback[_keySelectedProfileId] = id;
    }
  }

  Future<int?> getSelectedProfileId() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getInt(_keySelectedProfileId);
    }
    return _inMemoryFallback[_keySelectedProfileId] as int?;
  }

  Future<void> saveSelectedBoxId(int id) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setInt(_keySelectedBoxId, id);
    } else {
      _inMemoryFallback[_keySelectedBoxId] = id;
    }
  }

  Future<int?> getSelectedBoxId() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getInt(_keySelectedBoxId);
    }
    return _inMemoryFallback[_keySelectedBoxId] as int?;
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setString(_keyThemeMode, mode);
    } else {
      _inMemoryFallback[_keyThemeMode] = mode;
    }
  }

  Future<String?> getThemeMode() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getString(_keyThemeMode);
    }
    return _inMemoryFallback[_keyThemeMode] as String?;
  }
}
