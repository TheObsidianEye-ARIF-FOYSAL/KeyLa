import 'dart:math' as math;

import '../../features/vault/domain/credential.dart';

/// A lightweight, local, no-dependency strength heuristic. The password is
/// never sent anywhere to compute this — only the resulting enum is
/// persisted (see spec: never store the actual password unencrypted just to
/// derive `strength`).
class PasswordStrengthScorer {
  const PasswordStrengthScorer._();

  static PasswordStrength score(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    var pool = 0;
    if (password.contains(RegExp(r'[a-z]'))) pool += 26;
    if (password.contains(RegExp(r'[A-Z]'))) pool += 26;
    if (password.contains(RegExp(r'[0-9]'))) pool += 10;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) pool += 32;
    pool = pool == 0 ? 1 : pool;

    final entropyBits = password.length * (math.log(pool) / math.log(2));
    final variety = [
      password.contains(RegExp(r'[a-z]')),
      password.contains(RegExp(r'[A-Z]')),
      password.contains(RegExp(r'[0-9]')),
      password.contains(RegExp(r'[^a-zA-Z0-9]')),
    ].where((v) => v).length;

    if (entropyBits >= 80 && variety >= 3) return PasswordStrength.strong;
    if (entropyBits >= 45 && variety >= 2) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }
}
