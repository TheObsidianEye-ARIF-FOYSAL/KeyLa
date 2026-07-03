import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/cipher_service.dart';
import '../../../core/crypto/kdf_service.dart';
import '../../../core/db/credential_dao.dart';
import '../../../core/db/sqlcipher_key_service.dart';
import '../../../core/db/vault_database.dart';
import '../../../core/db/vault_meta_dao.dart';
import '../../../core/security/password_strength.dart';
import '../domain/credential.dart';

const _uuid = Uuid();

/// Thrown when the supplied master password does not unlock the vault.
class InvalidMasterPasswordException implements Exception {}

/// Owns the unlocked vault key in memory and mediates every read/write of a
/// [Credential] between the UI and the encrypted SQLCipher store. Nothing
/// that touches this class should ever persist a decrypted field.
class VaultRepository {
  VaultRepository({
    required SodiumSumo sodium,
    required VaultDatabase database,
  })  : _kdf = KdfService(sodium),
        _cipher = CipherService(sodium),
        _db = database,
        _metaDao = VaultMetaDao(database.db),
        _credentialDao = CredentialDao(database.db);

  final KdfService _kdf;
  final CipherService _cipher;
  final VaultDatabase _db;
  final VaultMetaDao _metaDao;
  final CredentialDao _credentialDao;

  SecureKey? _vaultKey;
  bool get isUnlocked => _vaultKey != null;

  KdfService get kdf => _kdf;

  /// Opens the local SQLCipher database (using a device-bound passphrase
  /// from secure storage, unrelated to the master password) and returns a
  /// repository over it. The vault itself still starts locked.
  static Future<VaultRepository> bootstrap({required SodiumSumo sodium}) async {
    final passphrase = await SqlcipherKeyService().getOrCreatePassphrase();
    final database = await VaultDatabase.open(passphrase);
    return VaultRepository(sodium: sodium, database: database);
  }

  /// First-run setup: generates a fresh vault key, wraps it under the
  /// unlock key derived from [masterPassword], and persists VaultMeta.
  Future<void> createVault(String masterPassword) async {
    final params = _kdf.generateParams();
    final unlockKey = _kdf.deriveVaultUnlockKey(masterPassword, params);
    final vaultKey = _cipher.generateVaultKey();
    final wrapped = _cipher.wrapVaultKey(vaultKey, unlockKey);

    await _metaDao.insert(VaultMetaRecord(
      wrappedVaultKey: wrapped,
      kdfParams: params,
      version: 1,
    ));

    unlockKey.dispose();
    _vaultKey = vaultKey;
  }

  /// Unlocks the vault with the master password, throwing
  /// [InvalidMasterPasswordException] on a wrong password.
  Future<void> unlock(String masterPassword) async {
    final meta = await _metaDao.read();
    if (meta == null) throw StateError('Vault has not been created yet');

    final unlockKey = _kdf.deriveVaultUnlockKey(masterPassword, meta.kdfParams);
    try {
      final vaultKey = _cipher.unwrapVaultKey(meta.wrappedVaultKey, unlockKey);
      _vaultKey = vaultKey;
    } catch (_) {
      throw InvalidMasterPasswordException();
    } finally {
      unlockKey.dispose();
    }
  }

  /// Changes the master password by re-wrapping the existing vault key
  /// under a freshly derived unlock key. Credential ciphertext is untouched.
  Future<void> changeMasterPassword(String newMasterPassword) async {
    final key = _requireVaultKey();
    final newParams = _kdf.generateParams();
    final newUnlockKey = _kdf.deriveVaultUnlockKey(newMasterPassword, newParams);
    final wrapped = _cipher.wrapVaultKey(key, newUnlockKey);
    await _metaDao.updateWrappedVaultKey(wrapped, newParams);
    newUnlockKey.dispose();
  }

  /// Clears the in-memory vault key. Must be called on background/timeout.
  void lock() {
    _vaultKey?.dispose();
    _vaultKey = null;
  }

  SecureKey _requireVaultKey() {
    final key = _vaultKey;
    if (key == null) throw StateError('Vault is locked');
    return key;
  }

  Future<List<Credential>> listCredentials() async {
    final key = _requireVaultKey();
    final rows = await _credentialDao.all();
    return rows.map((row) => _decrypt(row, key)).toList();
  }

  Future<Credential> addCredential({
    required String title,
    String? domain,
    String? androidPackage,
    required String username,
    required String password,
    String? notes,
    String? category,
    bool isFavorite = false,
  }) async {
    final key = _requireVaultKey();
    final now = DateTime.now().toUtc();
    final credential = Credential(
      id: _uuid.v4(),
      title: title,
      domain: domain,
      androidPackage: androidPackage,
      username: username,
      password: password,
      notes: notes,
      category: category,
      isFavorite: isFavorite,
      strength: PasswordStrengthScorer.score(password),
      createdAt: now,
      updatedAt: now,
    );
    await _credentialDao.upsert(_encrypt(credential, key));
    return credential;
  }

  Future<Credential> updateCredential(Credential credential) async {
    final key = _requireVaultKey();
    final updated = credential.copyWith(
      strength: PasswordStrengthScorer.score(credential.password),
      updatedAt: DateTime.now().toUtc(),
    );
    await _credentialDao.upsert(_encrypt(updated, key));
    return updated;
  }

  Future<void> deleteCredential(String id) => _credentialDao.delete(id);

  Future<void> markUsed(String id) =>
      _credentialDao.touchLastUsed(id, DateTime.now().toUtc().toIso8601String());

  CredentialRow _encrypt(Credential credential, SecureKey key) {
    return CredentialRow(
      id: credential.id,
      title: credential.title,
      domain: credential.domain,
      androidPackage: credential.androidPackage,
      username: _cipher.encryptString(credential.username, key),
      password: _cipher.encryptString(credential.password, key),
      notes: credential.notes == null ? null : _cipher.encryptString(credential.notes!, key),
      category: credential.category,
      isFavorite: credential.isFavorite,
      strength: credential.strength.name,
      createdAt: credential.createdAt.toIso8601String(),
      updatedAt: credential.updatedAt.toIso8601String(),
      lastUsedAt: credential.lastUsedAt?.toIso8601String(),
    );
  }

  Credential _decrypt(CredentialRow row, SecureKey key) {
    return Credential(
      id: row.id,
      title: row.title,
      domain: row.domain,
      androidPackage: row.androidPackage,
      username: _cipher.decryptString(row.username, key),
      password: _cipher.decryptString(row.password, key),
      notes: row.notes == null ? null : _cipher.decryptString(row.notes!, key),
      category: row.category,
      isFavorite: row.isFavorite,
      strength: PasswordStrength.values.byName(row.strength),
      createdAt: DateTime.parse(row.createdAt),
      updatedAt: DateTime.parse(row.updatedAt),
      lastUsedAt: row.lastUsedAt == null ? null : DateTime.parse(row.lastUsedAt!),
    );
  }

  static Future<bool> vaultExists() => VaultDatabase.exists();

  Future<void> close() async {
    lock();
    await _db.close();
  }
}
