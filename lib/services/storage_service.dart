import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyBaseUrl = 'app_api_base_url';
  static const String _keySelectedProfileId = 'app_selected_profile_id';
  static const String _keySelectedBoxId = 'app_selected_box_id';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyThemeModeLegacy = 'app_theme_mode';
  static const String _keyPrivacyConsentAccepted = 'privacy_consent_accepted';
  static const String _keyPrivacyConsentCloudSync = 'privacy_consent_cloud_sync';
  static const String _keyPrivacyConsentDate = 'privacy_consent_date';
  static const String _keyPrivacyConsentVersion = 'privacy_consent_version';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyBiometricEnabled = 'biometric_auth_enabled';
  static const String _keyPushEnabled = 'push_notifications_enabled';

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
      return prefs.getString(_keyThemeMode) ?? prefs.getString(_keyThemeModeLegacy);
    }
    return (_inMemoryFallback[_keyThemeMode] ?? _inMemoryFallback[_keyThemeModeLegacy]) as String?;
  }

  // 152-ФЗ Privacy Consent & Onboarding (T-5)
  Future<void> savePrivacyConsent({
    required bool accepted,
    bool cloudSync = false,
    String version = 'v1.0-2026',
    String? date,
  }) async {
    final prefs = await _getSafePrefs();
    final consentDate = date ?? DateTime.now().toIso8601String();
    if (prefs != null) {
      await prefs.setBool(_keyPrivacyConsentAccepted, accepted);
      await prefs.setBool(_keyPrivacyConsentCloudSync, cloudSync);
      await prefs.setString(_keyPrivacyConsentDate, consentDate);
      await prefs.setString(_keyPrivacyConsentVersion, version);
    } else {
      _inMemoryFallback[_keyPrivacyConsentAccepted] = accepted;
      _inMemoryFallback[_keyPrivacyConsentCloudSync] = cloudSync;
      _inMemoryFallback[_keyPrivacyConsentDate] = consentDate;
      _inMemoryFallback[_keyPrivacyConsentVersion] = version;
    }
  }

  Future<bool> isPrivacyConsentAccepted() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getBool(_keyPrivacyConsentAccepted) ?? false;
    }
    return (_inMemoryFallback[_keyPrivacyConsentAccepted] as bool?) ?? false;
  }

  Future<bool> isPrivacyConsentCloudSync() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getBool(_keyPrivacyConsentCloudSync) ?? false;
    }
    return (_inMemoryFallback[_keyPrivacyConsentCloudSync] as bool?) ?? false;
  }

  Future<String?> getPrivacyConsentDate() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getString(_keyPrivacyConsentDate);
    }
    return _inMemoryFallback[_keyPrivacyConsentDate] as String?;
  }

  Future<String?> getPrivacyConsentVersion() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getString(_keyPrivacyConsentVersion);
    }
    return _inMemoryFallback[_keyPrivacyConsentVersion] as String?;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setBool(_keyOnboardingCompleted, completed);
    } else {
      _inMemoryFallback[_keyOnboardingCompleted] = completed;
    }
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getBool(_keyOnboardingCompleted) ?? false;
    }
    return (_inMemoryFallback[_keyOnboardingCompleted] as bool?) ?? false;
  }

  Future<void> resetPrivacyConsent() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.remove(_keyPrivacyConsentAccepted);
      await prefs.remove(_keyPrivacyConsentCloudSync);
      await prefs.remove(_keyPrivacyConsentDate);
      await prefs.remove(_keyPrivacyConsentVersion);
      await prefs.remove(_keyOnboardingCompleted);
    } else {
      _inMemoryFallback.remove(_keyPrivacyConsentAccepted);
      _inMemoryFallback.remove(_keyPrivacyConsentCloudSync);
      _inMemoryFallback.remove(_keyPrivacyConsentDate);
      _inMemoryFallback.remove(_keyPrivacyConsentVersion);
      _inMemoryFallback.remove(_keyOnboardingCompleted);
    }
  }

  Future<void> clearAllData() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.remove(_keySelectedProfileId);
      await prefs.remove(_keySelectedBoxId);
      await prefs.remove(_keyPrivacyConsentAccepted);
      await prefs.remove(_keyPrivacyConsentCloudSync);
      await prefs.remove(_keyPrivacyConsentDate);
      await prefs.remove(_keyPrivacyConsentVersion);
      await prefs.remove(_keyOnboardingCompleted);
      await prefs.remove(_keyBiometricEnabled);
      await prefs.remove(_keyPushEnabled);
    }
    _inMemoryFallback.clear();
  }

  // Biometric Authentication (T-14)
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setBool(_keyBiometricEnabled, enabled);
    } else {
      _inMemoryFallback[_keyBiometricEnabled] = enabled;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getBool(_keyBiometricEnabled) ?? false;
    }
    return (_inMemoryFallback[_keyBiometricEnabled] as bool?) ?? false;
  }

  // Push Notifications (FCM)
  Future<void> setPushEnabled(bool enabled) async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      await prefs.setBool(_keyPushEnabled, enabled);
    } else {
      _inMemoryFallback[_keyPushEnabled] = enabled;
    }
  }

  Future<bool> isPushEnabled() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      return prefs.getBool(_keyPushEnabled) ?? false;
    }
    return (_inMemoryFallback[_keyPushEnabled] as bool?) ?? false;
  }
}
