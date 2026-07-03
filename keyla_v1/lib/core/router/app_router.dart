import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/presentation/user_auth_provider.dart';
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

/// Two stacked gates, checked in order on every navigation — mirroring
/// med_remind_v2's flow-gate state machine (Gate 1 account / Gate 2 vault),
/// just expressed as go_router redirects instead of a manual `_flow` field:
///   1. Account (phone+password, ARIF(KyLa) server) — [userAuthProvider].
///   2. Vault unlock (local master password) — [vaultUnlockedProvider].
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RiverpodRefreshNotifier(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final accountLoggedIn = ref.read(userAuthProvider).isLoggedIn;
      final vaultUnlocked = ref.read(vaultUnlockedProvider);

      if (loc == '/') return null; // splash screen resolves the initial gate itself

      if (!accountLoggedIn) {
        return loc == '/auth' ? null : '/auth';
      }

      const vaultGateRoutes = {'/onboarding', '/unlock'};
      if (!vaultUnlocked) {
        return vaultGateRoutes.contains(loc) ? null : '/unlock';
      }

      if (loc == '/auth' || vaultGateRoutes.contains(loc)) return '/vault';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const PhoneEntryScreen()),
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

/// Bridges both gate providers' changes into a [Listenable] so go_router
/// re-runs its redirect logic whenever either the account or vault state flips.
class _RiverpodRefreshNotifier extends ChangeNotifier {
  _RiverpodRefreshNotifier(Ref ref) {
    ref.listen(userAuthProvider, (_, _) => notifyListeners());
    ref.listen(vaultUnlockedProvider, (_, _) => notifyListeners());
  }
}
