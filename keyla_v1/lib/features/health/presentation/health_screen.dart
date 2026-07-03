import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../vault/domain/credential.dart';
import '../domain/health_report.dart';
import 'health_providers.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(healthReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Password Health')),
      body: reportAsync.when(
        data: (report) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: _ScoreRing(score: report.score)),
            const SizedBox(height: 24),
            if (report.issueCount == 0)
              const _AllGoodBanner()
            else ...[
              _IssueSection(
                title: 'Weak passwords',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
                items: report.weak,
              ),
              _IssueSection(
                title: 'Reused passwords',
                icon: Icons.content_copy_rounded,
                color: AppColors.warning,
                items: report.reused,
              ),
              _IssueSection(
                title: 'Old passwords (1yr+)',
                icon: Icons.history_rounded,
                color: AppColors.primary,
                items: report.old,
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? AppColors.success : (score >= 50 ? AppColors.warning : AppColors.danger);
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 12,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: color)),
              Text('out of 100', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllGoodBanner extends StatelessWidget {
  const _AllGoodBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.success, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Great job! No issues found across your saved passwords.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueSection extends StatelessWidget {
  const _IssueSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Credential> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text('$title (${items.length})', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((c) => Card(
                child: ListTile(
                  title: Text(c.title),
                  subtitle: Text(c.username),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/vault/${c.id}'),
                ),
              )),
        ],
      ),
    );
  }
}
