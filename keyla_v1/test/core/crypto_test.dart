import 'package:flutter_test/flutter_test.dart';
import 'package:keyla_v1/core/crypto/cipher_service.dart';
import 'package:keyla_v1/core/crypto/kdf_service.dart';
import 'package:keyla_v1/core/crypto/sodium_provider.dart';

void main() {
  group('crypto round-trip', () {
    test('deriving twice with the same params is deterministic', () async {
      final sodium = await SodiumProvider.instance();
      final kdf = KdfService(sodium);
      final params = kdf.generateParams();

      final key1 = kdf.deriveVaultUnlockKey('hunter2', params);
      final key2 = kdf.deriveVaultUnlockKey('hunter2', params);

      expect(key1.extractBytes(), equals(key2.extractBytes()));
      key1.dispose();
      key2.dispose();
    });

    test('cipher encrypts and decrypts a credential field', () async {
      final sodium = await SodiumProvider.instance();
      final cipher = CipherService(sodium);
      final key = cipher.generateVaultKey();

      final payload = cipher.encryptString('super-secret-password', key);
      final decrypted = cipher.decryptString(payload, key);

      expect(decrypted, 'super-secret-password');
      key.dispose();
    });

    test('envelope: vault key can be wrapped and unwrapped via the unlock key', () async {
      final sodium = await SodiumProvider.instance();
      final kdf = KdfService(sodium);
      final cipher = CipherService(sodium);
      final params = kdf.generateParams();

      final unlockKey = kdf.deriveVaultUnlockKey('master-pw', params);
      final vaultKey = cipher.generateVaultKey();

      final wrapped = cipher.wrapVaultKey(vaultKey, unlockKey);
      final unwrapped = cipher.unwrapVaultKey(wrapped, unlockKey);

      expect(unwrapped.extractBytes(), equals(vaultKey.extractBytes()));

      unlockKey.dispose();
      vaultKey.dispose();
      unwrapped.dispose();
    });

    test('tampered ciphertext fails to decrypt', () async {
      final sodium = await SodiumProvider.instance();
      final cipher = CipherService(sodium);
      final key = cipher.generateVaultKey();

      final payload = cipher.encryptString('data', key);
      final tampered = EncryptedPayload(
        nonce: payload.nonce,
        cipherText: payload.cipherText.replaceFirst(RegExp('.'), payload.cipherText[0] == 'A' ? 'B' : 'A'),
      );

      expect(() => cipher.decryptString(tampered, key), throwsA(anything));
      key.dispose();
    });
  });
}
