import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../features/generator/presentation/generator_screen.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/unlock/presentation/unlock_screen.dart';
import '../../features/vault/presentation/credential_detail_screen.dart';
import '../../features/vault/presentation/credential_form_screen.dart';
import '../../features/vault/presentation/splash_screen.dart';
import '../../features/vault/presentation/vault_home_screen.dart';
import '../providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RiverpodRefreshNotifier(ref, vaultUnlockedProvider),
    redirect: (context, state) {
      final unlocked = ref.read(vaultUnlockedProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/' || loc == '/onboarding' || loc == '/unlock';
      if (!unlocked && !isAuthRoute) return '/unlock';
      if (unlocked && (loc == '/unlock' || loc == '/onboarding' || loc == '/')) return '/vault';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const VaultHomeScreen()),
      GoRoute(
        path: '/vault/add',
        builder: (context, state) => const CredentialFormScreen(),
      ),
      GoRoute(
        path: '/vault/:id',
        builder: (context, state) => CredentialDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vault/:id/edit',
        builder: (context, state) => CredentialFormScreen(editId: state.pathParameters['id']),
      ),
      GoRoute(path: '/generator', builder: (context, state) => const GeneratorScreen()),
      GoRoute(path: '/health', builder: (context, state) => const HealthScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});

/// Bridges a Riverpod provider's changes into a [Listenable] so go_router
/// re-runs its redirect logic whenever the unlock state flips.
class _RiverpodRefreshNotifier extends ChangeNotifier {
  _RiverpodRefreshNotifier(Ref ref, StateProvider<bool> provider) {
    ref.listen(provider, (_, _) => notifyListeners());
  }
}
