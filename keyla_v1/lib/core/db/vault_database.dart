import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' as web;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Owns the SQLCipher-encrypted database file. The passphrase used to open
/// it is itself derived from the vault-unlock key (never the raw master
/// password), so the on-disk file is unreadable without a successful unlock.
///
/// **Web caveat.** `sqflite_sqlcipher` and `path_provider` are native-only, so
/// the browser build falls back to a plain (unencrypted) IndexedDB-backed
/// database via `sqflite_common_ffi_web`, exactly as `med_remind_v2` does.
/// Every credential field is *already* XChaCha20-Poly1305 sealed by
/// [CipherService] before it reaches this layer, so the stored rows are still
/// ciphertext — but the SQLCipher whole-file layer is absent, and the browser
/// build is a UI preview rather than a place to keep real secrets.
class VaultDatabase {
  VaultDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static const _fileName = 'keyla_vault.db';

  static Future<VaultDatabase> open(String passphraseHex) async {
    if (kIsWeb) {
      return VaultDatabase._(
        await web.databaseFactoryFfiWeb.openDatabase(
          _fileName,
          options: OpenDatabaseOptions(version: 1, onCreate: _createSchema),
        ),
      );
    }
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, _fileName);
    final db = await openDatabase(
      path,
      password: passphraseHex,
      version: 1,
      onCreate: _createSchema,
    );
    return VaultDatabase._(db);
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vault_meta (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        wrapped_vault_key_nonce TEXT NOT NULL,
        wrapped_vault_key_cipher TEXT NOT NULL,
        kdf_salt TEXT NOT NULL,
        kdf_ops_limit INTEGER NOT NULL,
        kdf_mem_limit INTEGER NOT NULL,
        version INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE credentials (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        domain TEXT,
        android_package TEXT,
        username_nonce TEXT NOT NULL,
        username_cipher TEXT NOT NULL,
        password_nonce TEXT NOT NULL,
        password_cipher TEXT NOT NULL,
        notes_nonce TEXT,
        notes_cipher TEXT,
        category TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        strength TEXT NOT NULL DEFAULT 'weak',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_used_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_credentials_title ON credentials(title)');
  }

  static Future<bool> exists() async {
    if (kIsWeb) return web.databaseFactoryFfiWeb.databaseExists(_fileName);
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName)).exists();
  }

  static Future<void> deleteAll() async {
    if (kIsWeb) return web.databaseFactoryFfiWeb.deleteDatabase(_fileName);
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, _fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> close() => _db.close();
}
