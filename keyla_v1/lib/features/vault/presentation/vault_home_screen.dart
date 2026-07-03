import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../health/presentation/health_providers.dart';
import 'credential_card.dart';
import 'vault_providers.dart';

class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(filteredCredentialsProvider);
    final favoritesOnly = ref.watch(vaultShowFavoritesOnlyProvider);
    final health = ref.watch(healthReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyla'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Password generator',
            onPressed: () => context.push('/generator'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateVault(ref),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: (v) => ref.read(vaultSearchQueryProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Search vault',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: health.when(
                        data: (report) => _HealthChip(score: report.score, onTap: () => context.push('/health')),
                        loading: () => const SizedBox(height: 44),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      label: const Text('Favorites'),
                      avatar: const Icon(Icons.star_rounded, size: 18),
                      selected: favoritesOnly,
                      onSelected: (v) => ref.read(vaultShowFavoritesOnlyProvider.notifier).state = v,
                    ),
                  ],
                ),
              ),
            ),
            credentialsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onAdd: () => context.push('/vault/add')),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 200 + i * 30),
                        builder: (context, value, child) => Opacity(opacity: value, child: child),
                        child: CredentialCard(
                          credential: c,
                          onTap: () => context.push('/vault/${c.id}'),
                          onDelete: () async {
                            final repo = await ref.read(vaultRepositoryProvider.future);
                            await repo.deleteCredential(c.id);
                            invalidateVault(ref);
                          },
                          onToggleFavorite: () async {
                            final repo = await ref.read(vaultRepositoryProvider.future);
                            await repo.updateCredential(c.copyWith(isFavorite: !c.isFavorite));
                            invalidateVault(ref);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/vault/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.score, required this.onTap});
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? AppColors.success : (score >= 50 ? AppColors.warning : AppColors.danger);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety_outlined, color: color, size: 18),
            const SizedBox(width: 8),
            Text('Password health: $score/100', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 16),
            Text('Your vault is empty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first password and Keyla will keep it encrypted and ready to fill.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAdd, child: const Text('Add your first password')),
          ],
        ),
      ),
    );
  }
}
