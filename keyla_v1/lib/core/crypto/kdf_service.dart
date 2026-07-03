import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';

/// Parameters needed to re-derive a key from a master password later.
/// Safe to store unencrypted alongside the vault (this is standard practice
/// for a KDF salt + cost parameters).
class KdfParams {
  const KdfParams({
    required this.opsLimit,
    required this.memLimit,
    required this.salt,
  });

  final int opsLimit;
  final int memLimit;
  final String salt; // base64, crypto_pwhash salt bytes

  Map<String, dynamic> toJson() => {
        'opsLimit': opsLimit,
        'memLimit': memLimit,
        'salt': salt,
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
        opsLimit: json['opsLimit'] as int,
        memLimit: json['memLimit'] as int,
        salt: json['salt'] as String,
      );
}

/// Argon2id-based key derivation from the user's master password.
///
/// Two secrets are derived from the *same* master password using
/// domain-separated sub-salts: [deriveVaultUnlockKey] (never leaves the
/// device) and [deriveServerAuthSecret] (sent to the ARIF(KyLa) backend as the
/// login credential). Because the sub-salts differ, a server-side breach of
/// the auth secret cannot be used to reconstruct the vault-unlock key, even
/// though both start from the same master password.
class KdfService {
  KdfService(this._sodium);

  final SodiumSumo _sodium;

  static const int keyBytes = 32;

  /// Generates fresh KDF params with a random salt, using the "moderate"
  /// libsodium cost profile (a reasonable interactive/mobile balance).
  KdfParams generateParams() {
    final salt = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
    return KdfParams(
      opsLimit: _sodium.crypto.pwhash.opsLimitModerate,
      memLimit: _sodium.crypto.pwhash.memLimitModerate,
      salt: base64Encode(salt),
    );
  }

  Uint8List _domainSalt(Uint8List baseSalt, String domain) {
    final key = SecureKey.fromList(
      _sodium,
      Uint8List.fromList(
        utf8.encode(domain).length >= _sodium.crypto.genericHash.keyBytesMin
            ? utf8.encode(domain)
            : utf8.encode(domain.padRight(_sodium.crypto.genericHash.keyBytesMin, '.')),
      ),
    );
    try {
      return _sodium.crypto.genericHash(
        message: baseSalt,
        key: key,
        outLen: _sodium.crypto.pwhash.saltBytes,
      );
    } finally {
      key.dispose();
    }
  }

  SecureKey _derive(String password, KdfParams params, String domain) {
    final baseSalt = base64Decode(params.salt);
    final salt = _domainSalt(baseSalt, domain);
    final passwordBytes = utf8.encode(password);
    final int8Password = Int8List.fromList(passwordBytes);
    return _sodium.crypto.pwhash(
      outLen: keyBytes,
      password: int8Password,
      salt: salt,
      opsLimit: params.opsLimit,
      memLimit: params.memLimit,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
  }

  /// Derives the local vault-unlock key. Caller owns the returned
  /// [SecureKey] and must [SecureKey.dispose] it when done.
  SecureKey deriveVaultUnlockKey(String masterPassword, KdfParams params) =>
      _derive(masterPassword, params, 'keyla.vault-unlock.v1......');

  /// Derives the secret sent to the ARIF(KyLa) server as the login
  /// credential. Caller owns the returned [SecureKey].
  SecureKey deriveServerAuthSecret(String masterPassword, KdfParams params) =>
      _derive(masterPassword, params, 'keyla.server-auth.v1.......');
}
