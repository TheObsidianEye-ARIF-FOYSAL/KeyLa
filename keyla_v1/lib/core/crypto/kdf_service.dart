import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

/// Argon2id-based key derivation.
///
/// Two derivations come from the same master password, using distinct
/// domain-separated salts, so a server-side compromise of [deriveServerAuthKey]
/// can never be combined with a stolen device to reconstruct the vault key.
class KdfParams {
  const KdfParams({
    required this.opsLimit,
    required this.memLimit,
    required this.salt,
  });

  final int opsLimit;
  final int memLimit;
  final String salt; // base64

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

class KdfService {
  KdfService(this._sodium);

  final Sodium _sodium;

  static const int keyBytes = 32;

  /// Generates fresh KDF params (random salt) at the sensitive/interactive
  /// balance recommended for mobile devices.
  KdfParams generateParams() {
    final salt = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
    return KdfParams(
      opsLimit: _sodium.crypto.pwhash.opsLimitModerate,
      memLimit: _sodium.crypto.pwhash.memLimitModerate,
      salt: base64Encode(salt),
    );
  }

  Uint8List _derive(String password, KdfParams params, String domain) {
    // Domain separation: fold a short context tag into the salt material via
    // a distinct sub-salt derived from SHA-256(salt || domain), so the vault
    // key and server-auth key never collide even if params are reused.
    final baseSalt = base64Decode(params.salt);
    final domainSalt = _sodium.crypto.genericHash(
      message: Uint8List.fromList(utf8.encode(domain)),
      key: baseSalt.length >= _sodium.crypto.genericHash.keyBytesMin
          ? baseSalt.sublist(0, _sodium.crypto.genericHash.keyBytesMin)
          : null,
      outLen: _sodium.crypto.pwhash.saltBytes,
    );

    return _sodium.crypto.pwhash(
      outLen: keyBytes,
      password: Int8List.fromList(utf8.encode(password)),
      salt: domainSalt,
      opsLimit: params.opsLimit,
      memLimit: params.memLimit,
      alg: _sodium.crypto.pwhash.algArgon2id13,
    );
  }

  /// Derives the local vault-unlock key. Never leaves the device.
  Uint8List deriveVaultUnlockKey(String masterPassword, KdfParams params) =>
      _derive(masterPassword, params, 'keyla.vault-unlock.v1');

  /// Derives a separate secret sent to the ARIF(KyLa) server as the login
  /// credential. Cannot be used to derive the vault-unlock key.
  Uint8List deriveServerAuthSecret(String masterPassword, KdfParams params) =>
      _derive(masterPassword, params, 'keyla.server-auth.v1');
}
