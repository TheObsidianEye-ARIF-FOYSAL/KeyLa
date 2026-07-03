import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/crypto/kdf_service.dart';
import '../../vault/data/vault_repository.dart';
import 'sync_client.dart';

/// Coordinates account register/login and vault backup/restore against the
/// ARIF(KyLa) server. The master password itself never leaves this class —
/// only [KdfService.deriveServerAuthSecret]'s output does, and only the
/// vault's existing ciphertext is uploaded (see [VaultRepository.exportForSync]).
class SyncService {
  SyncService({required this.client, required this.repository});

  final SyncClient client;
  final VaultRepository repository;
  final _storage = const FlutterSecureStorage();

  static const _kEmail = 'sync_email';
  static const _kToken = 'sync_token';

  Future<bool> isLinked() async => (await _storage.read(key: _kToken)) != null;

  Future<String?> linkedEmail() => _storage.read(key: _kEmail);

  Future<void> _saveSession(String email, String token) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kToken, value: token);
  }

  Future<void> unlink() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kToken);
  }

  Future<void> register({required String email, required String masterPassword}) async {
    final params = await repository.currentKdfParams();
    final secret = repository.kdf.deriveServerAuthSecret(masterPassword, params);
    final secretB64 = base64Encode(secret.extractBytes());
    secret.dispose();
    final result = await client.register(email: email, serverAuthSecretBase64: secretB64);
    await _saveSession(email, result['token'] as String);
  }

  Future<void> login({required String email, required String masterPassword}) async {
    final params = await repository.currentKdfParams();
    final secret = repository.kdf.deriveServerAuthSecret(masterPassword, params);
    final secretB64 = base64Encode(secret.extractBytes());
    secret.dispose();
    final result = await client.login(email: email, serverAuthSecretBase64: secretB64);
    await _saveSession(email, result['token'] as String);
  }

  Future<void> backupNow() async {
    final email = await _storage.read(key: _kEmail);
    final token = await _storage.read(key: _kToken);
    if (email == null || token == null) throw StateError('Not linked to a backup account');

    final export = await repository.exportForSync();
    final params = await repository.currentKdfParams();
    await client.uploadVault(
      email: email,
      token: token,
      blobBase64: base64Encode(utf8.encode(jsonEncode(export))),
      kdfSalt: params.salt,
      kdfParams: params.toJson(),
      version: 1,
    );
  }

  Future<void> restoreNow() async {
    final email = await _storage.read(key: _kEmail);
    final token = await _storage.read(key: _kToken);
    if (email == null || token == null) throw StateError('Not linked to a backup account');

    final response = await client.downloadVault(email: email, token: token);
    if (response == null) throw StateError('No backup found for this account');

    final export = jsonDecode(utf8.decode(base64Decode(response['blob'] as String))) as Map<String, dynamic>;
    final kdfParams = KdfParams.fromJson(response['kdfParams'] as Map<String, dynamic>);
    await repository.importFromSync(export, kdfParams);
  }
}
