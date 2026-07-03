/// The Keyla account identity — phone + display name, verified against the
/// ARIF(KyLa) server. Deliberately unrelated to the vault's master
/// password: this only gates "is this device signed in to an account,"
/// never the vault's zero-knowledge encryption key.
class AppUser {
  const AppUser({required this.phone, required this.name});

  final String phone;
  final String name;
}
