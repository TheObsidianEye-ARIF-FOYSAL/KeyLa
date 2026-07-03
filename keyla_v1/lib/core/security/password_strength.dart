import '../../features/vault/domain/credential.dart';

/// A lightweight, local, no-dependency strength heuristic. Never sends the
/// password anywhere to compute this — see spec: "never store the actual
/// password unencrypted to compute [strength]" (only the derived enum is
/// persisted).
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

    final entropyBits = password.length * (_log2(pool));
    final hasVariety = [
      password.contains(RegExp(r'[a-z]')),
      password.contains(RegExp(r'[A-Z]')),
      password.contains(RegExp(r'[0-9]')),
      password.contains(RegExp(r'[^a-zA-Z0-9]')),
    ].where((v) => v).length;

    if (entropyBits >= 80 && hasVariety >= 3) return PasswordStrength.strong;
    if (entropyBits >= 45 && hasVariety >= 2) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  static double _log2(num x) => x <= 0 ? 0 : (_ln(x) / _ln2);
  static final _ln2 = _ln(2);
  static double _ln(num x) => x <= 0 ? 0 : (x == 1 ? 0 : _naturalLog(x));

  static double _naturalLog(num x) {
    // dart:math.log, imported lazily to keep this file dependency-free at a glance.
    return _mathLog(x.toDouble());
  }
}

// Kept as a tiny indirection so the class above reads cleanly; delegates
// straight to dart:math.
double _mathLog(double x) => _log(x);

// ignore: unused_import
import 'dart:math' as math show log;
double _log(double x) => math.log(x);
