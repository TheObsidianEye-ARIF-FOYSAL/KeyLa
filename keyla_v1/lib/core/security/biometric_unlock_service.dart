import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores a biometric-gated copy of the master password in the platform
/// Keychain/Keystore (spec §5: "store a biometric-gated copy of the wrapped
/// key in Keychain/Keystore, released only after successful biometric
/// auth"). Biometrics are a convenience layer only — they never bypass the
/// Argon2id-derived unlock path, they just supply the same master password
/// to it after a successful biometric check.
class BiometricUnlockService {
  BiometricUnlockService()
      : _auth = LocalAuthentication(),
        _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        );

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _key = 'biometric_master_password';

  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  Future<void> enroll(String masterPassword) async {
    await _storage.write(key: _key, value: masterPassword);
  }

  Future<void> disable() async {
    await _storage.delete(key: _key);
  }

  Future<bool> isEnrolled() async => (await _storage.read(key: _key)) != null;

  /// Prompts biometric auth, and if successful, returns the stored master
  /// password so the caller can run it through the normal unlock path.
  Future<String?> authenticateAndFetchPassword() async {
    final authenticated = await _auth.authenticate(
      localizedReason: 'Unlock your Keyla vault',
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
    if (!authenticated) return null;
    return _storage.read(key: _key);
  }
}
