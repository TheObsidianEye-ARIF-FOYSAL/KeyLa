import '../../vault/domain/credential.dart';

class HealthReport {
  const HealthReport({
    required this.score,
    required this.weak,
    required this.reused,
    required this.old,
  });

  final int score; // 0-100
  final List<Credential> weak;
  final List<Credential> reused;
  final List<Credential> old;

  int get issueCount => weak.length + reused.length + old.length;

  static HealthReport compute(List<Credential> credentials) {
    if (credentials.isEmpty) {
      return const HealthReport(score: 100, weak: [], reused: [], old: []);
    }

    final weak = credentials.where((c) => c.strength != PasswordStrength.strong).toList();

    final byPassword = <String, List<Credential>>{};
    for (final c in credentials) {
      byPassword.putIfAbsent(c.password, () => []).add(c);
    }
    final reused = byPassword.values.where((v) => v.length > 1).expand((v) => v).toList();

    final oldCutoff = DateTime.now().subtract(const Duration(days: 365));
    final old = credentials.where((c) => c.updatedAt.isBefore(oldCutoff)).toList();

    final troubled = {...weak, ...reused, ...old}.length;
    final score = (100 - (troubled / credentials.length * 100)).clamp(0, 100).round();

    return HealthReport(score: score, weak: weak, reused: reused, old: old);
  }
}
