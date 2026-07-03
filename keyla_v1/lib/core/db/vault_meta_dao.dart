import 'package:sqflite_sqlcipher/sqflite.dart';

import '../crypto/cipher_service.dart';
import '../crypto/kdf_service.dart';

class VaultMetaRecord {
  const VaultMetaRecord({
    required this.wrappedVaultKey,
    required this.kdfParams,
    required this.version,
  });

  final EncryptedPayload wrappedVaultKey;
  final KdfParams kdfParams;
  final int version;
}

class VaultMetaDao {
  VaultMetaDao(this._db);

  final Database _db;

  Future<void> insert(VaultMetaRecord record) async {
    await _db.insert('vault_meta', {
      'id': 0,
      'wrapped_vault_key_nonce': record.wrappedVaultKey.nonce,
      'wrapped_vault_key_cipher': record.wrappedVaultKey.cipherText,
      'kdf_salt': record.kdfParams.salt,
      'kdf_ops_limit': record.kdfParams.opsLimit,
      'kdf_mem_limit': record.kdfParams.memLimit,
      'version': record.version,
    });
  }

  Future<VaultMetaRecord?> read() async {
    final rows = await _db.query('vault_meta', where: 'id = 0', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return VaultMetaRecord(
      wrappedVaultKey: EncryptedPayload(
        nonce: row['wrapped_vault_key_nonce'] as String,
        cipherText: row['wrapped_vault_key_cipher'] as String,
      ),
      kdfParams: KdfParams(
        opsLimit: row['kdf_ops_limit'] as int,
        memLimit: row['kdf_mem_limit'] as int,
        salt: row['kdf_salt'] as String,
      ),
      version: row['version'] as int,
    );
  }

  Future<void> updateWrappedVaultKey(EncryptedPayload wrapped, KdfParams params) async {
    await _db.update(
      'vault_meta',
      {
        'wrapped_vault_key_nonce': wrapped.nonce,
        'wrapped_vault_key_cipher': wrapped.cipherText,
        'kdf_salt': params.salt,
        'kdf_ops_limit': params.opsLimit,
        'kdf_mem_limit': params.memLimit,
      },
      where: 'id = 0',
    );
  }
}
