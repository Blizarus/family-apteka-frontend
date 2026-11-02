import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'storage_service.dart';

/// Service providing biometric authentication (Touch ID, Face ID, fingerprint).
/// Uses LocalAuthentication in production, supports mock mode for tests and non-hardware environments.
class BiometricService {
  final LocalAuthentication _localAuth;
  StorageService? _storageService;
  bool isMockMode;
  bool mockAuthResult;
  bool mockAvailable;

  BiometricService({
    LocalAuthentication? localAuth,
    StorageService? storageService,
    bool? isMockMode,
    this.mockAuthResult = true,
    this.mockAvailable = true,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        isMockMode = isMockMode ?? !kReleaseMode {
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

  /// Checks whether biometric authentication is supported and enrolled on the device.
  /// Gracefully returns false if no biometric hardware or enrolled prints exist.
  Future<bool> isBiometricAvailable() async {
    if (isMockMode) {
      return mockAvailable;
    }

    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canAuthenticateWithBiometrics || !isDeviceSupported) {
        return false;
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric authentication with the given [localizedReason].
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    if (isMockMode) {
      return mockAuthResult;
    }

    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
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
