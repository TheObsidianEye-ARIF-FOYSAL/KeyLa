import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'crypto/sodium_provider.dart';
import 'security/auto_lock_controller.dart';
import 'security/biometric_unlock_service.dart';
import 'security/clipboard_guard.dart';
import '../features/settings/data/settings_service.dart';
import '../features/vault/data/vault_repository.dart';

final sodiumProvider = FutureProvider<SodiumSumo>((ref) => SodiumProvider.instance());

final settingsServiceProvider = FutureProvider<SettingsService>((ref) => SettingsService.load());

final biometricUnlockServiceProvider = Provider<BiometricUnlockService>((ref) {
  return BiometricUnlockService();
});

final clipboardGuardProvider = Provider<ClipboardGuard>((ref) {
  final guard = ClipboardGuard();
  ref.onDispose(guard.dispose);
  return guard;
});

/// Holds the single [VaultRepository] instance for the app's lifetime once
/// the sodium bindings are ready. The repository itself starts locked; call
/// [VaultRepository.createVault] or [VaultRepository.unlock] to proceed.
final vaultRepositoryProvider = FutureProvider<VaultRepository>((ref) async {
  final sodium = await ref.watch(sodiumProvider.future);
  return VaultRepository.bootstrap(sodium: sodium);
});

/// Tracks whether the vault is currently unlocked, so the router can guard
/// routes and screens can react to an auto-lock event.
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);

final autoLockControllerProvider = Provider<AutoLockController>((ref) {
  final controller = AutoLockController(
    onLock: () => ref.read(vaultUnlockedProvider.notifier).state = false,
  );
  ref.onDispose(controller.disarm);
  return controller;
});
