import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The SQLCipher database passphrase is a random, device-bound secret held
/// in the Keystore/Keychain — separate from (and unrelated to) the user's
/// master password. It gives the vault file at-rest disk encryption even
/// before the user unlocks anything; the actual zero-knowledge guarantee
/// comes from the master-password-derived vault key that field-encrypts
/// each credential (see VaultRepository / KdfService), which this key
/// cannot substitute for.
class SqlcipherKeyService {
  SqlcipherKeyService()
      : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'sqlcipher_db_passphrase';

  Future<String> getOrCreatePassphrase() async {
    final existing = await _storage.read(key: _key);
    if (existing != null) return existing;

    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final passphrase = base64UrlEncode(bytes);
    await _storage.write(key: _key, value: passphrase);
    return passphrase;
  }
}
