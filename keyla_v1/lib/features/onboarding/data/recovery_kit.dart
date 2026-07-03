import 'dart:math';

/// Generates a printable recovery code. This is presentational only — the
/// master password remains unrecoverable by design (zero-knowledge); the
/// code is just something the user can write down, not a working backdoor
/// into a real backend recovery flow in this build.
class RecoveryKit {
  const RecoveryKit._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars

  static String generate() {
    final rand = Random.secure();
    final groups = List.generate(5, (_) {
      return List.generate(4, (_) => _alphabet[rand.nextInt(_alphabet.length)]).join();
    });
    return groups.join('-');
  }
}
