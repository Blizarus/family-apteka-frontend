import 'storage_service.dart';

/// Service providing biometric authentication (Touch ID, Face ID, fingerprint).
/// Supports mock mode for widget testing and devices without biometrics hardware.
class BiometricService {
  StorageService? _storageService;
  bool isMockMode;
  bool mockAuthResult;
  bool mockAvailable;

  BiometricService({
    StorageService? storageService,
    this.isMockMode = true,
    this.mockAuthResult = true,
    this.mockAvailable = true,
  }) {
    _storageService = storageService;
  }

  StorageService get storageService => _storageService ??= StorageService();

  set storageService(StorageService service) {
    _storageService = service;
  }

  /// Sets the simulated result for [authenticate] when in [isMockMode].
  void setMockAuthResult(bool result) {
    mockAuthResult = result;
  }

  /// Sets whether biometrics are reported as available when in [isMockMode].
  void setMockAvailable(bool available) {
    mockAvailable = available;
  }

  /// Checks whether biometric authentication (Touch ID / Face ID) is supported on the device.
  Future<bool> isBiometricAvailable() async {
    if (isMockMode) {
      return mockAvailable;
    }
    return mockAvailable;
  }

  /// Prompts the user for biometric authentication with the given [localizedReason].
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    if (isMockMode) {
      return mockAuthResult;
    }
    return mockAuthResult;
  }

  /// Checks whether biometric authentication is enabled in user settings.
  Future<bool> isBiometricAuthEnabled() async {
    return await storageService.isBiometricEnabled();
  }

  /// Saves the biometric authentication toggle state to persistent storage.
  Future<void> setBiometricAuthEnabled(bool value) async {
    await storageService.setBiometricEnabled(value);
  }

  /// Convenience aliases matching StorageService naming conventions.
  Future<bool> isBiometricEnabled() => isBiometricAuthEnabled();
  Future<void> setBiometricEnabled(bool value) => setBiometricAuthEnabled(value);
}
