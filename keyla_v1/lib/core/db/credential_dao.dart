import 'package:sqflite_sqlcipher/sqflite.dart';

import '../crypto/cipher_service.dart';

/// Raw row shape as stored on disk: everything sensitive is already
/// ciphertext by the time it reaches this DAO.
class CredentialRow {
  const CredentialRow({
    required this.id,
    required this.title,
    this.domain,
    this.androidPackage,
    required this.username,
    required this.password,
    this.notes,
    this.category,
    required this.isFavorite,
    required this.strength,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  final String id;
  final String title;
  final String? domain;
  final String? androidPackage;
  final EncryptedPayload username;
  final EncryptedPayload password;
  final EncryptedPayload? notes;
  final String? category;
  final bool isFavorite;
  final String strength;
  final String createdAt;
  final String updatedAt;
  final String? lastUsedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'domain': domain,
        'android_package': androidPackage,
        'username_nonce': username.nonce,
        'username_cipher': username.cipherText,
        'password_nonce': password.nonce,
        'password_cipher': password.cipherText,
        'notes_nonce': notes?.nonce,
        'notes_cipher': notes?.cipherText,
        'category': category,
        'is_favorite': isFavorite ? 1 : 0,
        'strength': strength,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'last_used_at': lastUsedAt,
      };

  static CredentialRow fromMap(Map<String, dynamic> row) => CredentialRow(
        id: row['id'] as String,
        title: row['title'] as String,
        domain: row['domain'] as String?,
        androidPackage: row['android_package'] as String?,
        username: EncryptedPayload(
          nonce: row['username_nonce'] as String,
          cipherText: row['username_cipher'] as String,
        ),
        password: EncryptedPayload(
          nonce: row['password_nonce'] as String,
          cipherText: row['password_cipher'] as String,
        ),
        notes: row['notes_nonce'] == null
            ? null
            : EncryptedPayload(
                nonce: row['notes_nonce'] as String,
                cipherText: row['notes_cipher'] as String,
              ),
        category: row['category'] as String?,
        isFavorite: (row['is_favorite'] as int) == 1,
        strength: row['strength'] as String,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
        lastUsedAt: row['last_used_at'] as String?,
      );
}

class CredentialDao {
  CredentialDao(this._db);

  final Database _db;

  Future<void> upsert(CredentialRow row) async {
    await _db.insert(
      'credentials',
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('credentials', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CredentialRow>> all() async {
    final rows = await _db.query('credentials', orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(CredentialRow.fromMap).toList();
  }

  Future<void> touchLastUsed(String id, String isoTimestamp) async {
    await _db.update(
      'credentials',
      {'last_used_at': isoTimestamp},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
