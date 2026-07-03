import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';

/// Ciphertext + nonce, base64-encoded, ready to persist. The Poly1305 auth
/// tag is appended to the ciphertext by libsodium's combined-mode API.
class EncryptedPayload {
  const EncryptedPayload({required this.nonce, required this.cipherText});

  final String nonce; // base64
  final String cipherText; // base64 (ciphertext || auth tag)

  Map<String, dynamic> toJson() => {'nonce': nonce, 'cipherText': cipherText};

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        nonce: json['nonce'] as String,
        cipherText: json['cipherText'] as String,
      );
}

/// Encrypts/decrypts individual fields with XChaCha20-Poly1305, using a
/// unique random nonce per call. Never reuses a nonce for a given key.
class CipherService {
  CipherService(this._sodium);

  final SodiumSumo _sodium;

  EncryptedPayload encryptString(String plainText, SecureKey key) {
    final nonce = _sodium.randombytes.buf(
      _sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );
    final cipherText = _sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: Uint8List.fromList(utf8.encode(plainText)),
      nonce: nonce,
      key: key,
    );
    return EncryptedPayload(
      nonce: base64Encode(nonce),
      cipherText: base64Encode(cipherText),
    );
  }

  String decryptString(EncryptedPayload payload, SecureKey key) {
    final plain = _sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: base64Decode(payload.cipherText),
      nonce: base64Decode(payload.nonce),
      key: key,
    );
    return utf8.decode(plain);
  }

  /// Generates a random vault key.
  SecureKey generateVaultKey() =>
      SecureKey.random(_sodium, _sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes);

  /// Envelope-wraps the vault key under the unlock key derived from the
  /// master password, for storage in VaultMeta.
  EncryptedPayload wrapVaultKey(SecureKey vaultKey, SecureKey unlockKey) =>
      vaultKey.runUnlockedSync(
        (bytes) => encryptString(base64Encode(bytes), unlockKey),
      );

  SecureKey unwrapVaultKey(EncryptedPayload wrapped, SecureKey unlockKey) {
    final decoded = base64Decode(decryptString(wrapped, unlockKey));
    return SecureKey.fromList(_sodium, decoded);
  }
}
