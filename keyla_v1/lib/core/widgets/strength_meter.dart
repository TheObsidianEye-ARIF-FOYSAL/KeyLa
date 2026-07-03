import 'package:flutter/material.dart';

import '../security/password_strength.dart';
import '../theme/app_colors.dart';
import '../../features/vault/domain/credential.dart';

/// Animated segmented strength meter (spec §8.3) with a plain-language
/// label, driven purely from a local heuristic — the password never leaves
/// this widget's build method.
class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthScorer.score(password);
    final index = PasswordStrength.values.indexOf(strength);
    final color = AppColors.strengthColor(index);
    final segments = 3;
    final filled = index + 1;

    final label = switch (strength) {
      PasswordStrength.weak => password.isEmpty ? 'Enter a password' : 'Weak — try adding more characters',
      PasswordStrength.fair => 'Fair — getting stronger',
      PasswordStrength.strong => 'Strong password',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(segments, (i) {
            final isFilled = i < filled && password.isNotEmpty;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 6),
                height: 6,
                decoration: BoxDecoration(
                  color: isFilled ? color : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
