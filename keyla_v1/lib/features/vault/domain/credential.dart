enum PasswordStrength { weak, fair, strong }

/// A fully-decrypted credential, only ever held in memory while the vault
/// is unlocked. Never persisted or logged in this shape.
class Credential {
  const Credential({
    required this.id,
    required this.title,
    this.domain,
    this.androidPackage,
    required this.username,
    required this.password,
    this.notes,
    this.category,
    this.isFavorite = false,
    this.strength = PasswordStrength.weak,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  final String id;
  final String title;
  final String? domain;
  final String? androidPackage;
  final String username;
  final String password;
  final String? notes;
  final String? category;
  final bool isFavorite;
  final PasswordStrength strength;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  Credential copyWith({
    String? title,
    String? domain,
    String? androidPackage,
    String? username,
    String? password,
    String? notes,
    String? category,
    bool? isFavorite,
    PasswordStrength? strength,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return Credential(
      id: id,
      title: title ?? this.title,
      domain: domain ?? this.domain,
      androidPackage: androidPackage ?? this.androidPackage,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      strength: strength ?? this.strength,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
