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

/// Argon2id-based key derivation from the user's Keyla master password.
///
/// This key never leaves the device and is unrelated to the ARIF(KyLa)
/// account password (see features/auth) — that's a separate plain
/// phone+password credential verified server-side, exactly like
/// MedRemind's account gate. Keeping the two decoupled means a server
/// compromise of the account password can never expose vault contents.
class KdfService {
  KdfService(this._sodium);

  final SodiumSumo _sodium;

  static const int keyBytes = 32;
  static const String _vaultUnlockDomain = 'keyla.vault-unlock.v1......';

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
    final key = SecureKey.fromList(_sodium, Uint8List.fromList(utf8.encode(domain)));
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

  /// Derives the local vault-unlock key. Caller owns the returned
  /// [SecureKey] and must [SecureKey.dispose] it when done.
  SecureKey deriveVaultUnlockKey(String masterPassword, KdfParams params) {
    final salt = _domainSalt(base64Decode(params.salt), _vaultUnlockDomain);
    final int8Password = Int8List.fromList(utf8.encode(masterPassword));
    return _sodium.crypto.pwhash(
      outLen: keyBytes,
      password: int8Password,
      salt: salt,
      opsLimit: params.opsLimit,
      memLimit: params.memLimit,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
  }
}
