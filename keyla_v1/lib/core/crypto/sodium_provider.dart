import 'package:sodium_libs/sodium_libs_sumo.dart';

/// Lazily initializes the libsodium sumo bindings (needed for crypto_pwhash /
/// Argon2id, which is not part of the minimal API surface).
class SodiumProvider {
  SodiumProvider._();

  static SodiumSumo? _instance;

  static Future<SodiumSumo> instance() async {
    return _instance ??= await SodiumSumoInit.init();
  }
}
