import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';

/// Decides where to send the user on cold start: onboarding (no vault yet)
/// or the lock screen (vault exists but is locked).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final repo = await ref.read(vaultRepositoryProvider.future);
    final hasVault = await repo.hasVaultMeta();
    if (!mounted) return;
    context.go(hasVault ? '/unlock' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Icon(Icons.shield_outlined, size: 64, color: AppColors.primary),
      ),
    );
  }
}
