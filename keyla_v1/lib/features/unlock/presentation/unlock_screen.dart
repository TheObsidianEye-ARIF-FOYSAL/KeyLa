import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/screen_privacy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import '../../vault/data/vault_repository.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  late final AnimationController _shieldController;
  bool _unlocking = false;
  String? _error;
  bool _triedBiometricThisSession = false;

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    ScreenPrivacy.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoTryBiometricOnce());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shieldController.dispose();
    super.dispose();
  }

  Future<void> _autoTryBiometricOnce() async {
    if (_triedBiometricThisSession) return;
    _triedBiometricThisSession = true;
    await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!settings.biometricEnabled) return;
    final biometrics = ref.read(biometricUnlockServiceProvider);
    if (!await biometrics.isEnrolled()) return;
    final password = await biometrics.authenticateAndFetchPassword();
    if (password != null) {
      await _unlockWith(password);
    }
  }

  Future<void> _unlockWith(String password) async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final repo = await ref.read(vaultRepositoryProvider.future);
      await repo.unlock(password);
      await _shieldController.forward();
      ref.read(vaultUnlockedProvider.notifier).state = true;
      ref.read(autoLockControllerProvider).arm();
      if (mounted) context.go('/vault');
    } on InvalidMasterPasswordException {
      setState(() => _error = 'Incorrect master password');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 0.85).animate(
                  CurvedAnimation(parent: _shieldController, curve: Curves.easeOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text('Keyla is locked', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              SecretField(
                controller: _passwordController,
                label: 'Master password',
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _unlocking ? null : () => _unlockWith(_passwordController.text),
                  child: _unlocking
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Unlock'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use biometrics'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
