import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import '../../../core/widgets/strength_meter.dart';
import '../data/recovery_kit.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _page = 0;
  bool _biometricWanted = false;
  bool _creating = false;
  String? _passwordError;
  late final String _recoveryCode;

  static const _pageCount = 5;

  @override
  void initState() {
    super.initState();
    _recoveryCode = RecoveryKit.generate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 2 && !_validatePassword()) return;
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  bool _validatePassword() {
    final pw = _passwordController.text;
    if (pw.length < 8) {
      setState(() => _passwordError = 'Use at least 8 characters');
      return false;
    }
    if (pw != _confirmController.text) {
      setState(() => _passwordError = "Passwords don't match");
      return false;
    }
    setState(() => _passwordError = null);
    return true;
  }

  Future<void> _finish() async {
    setState(() => _creating = true);
    try {
      final repo = await ref.read(vaultRepositoryProvider.future);
      await repo.createVault(_passwordController.text);

      if (_biometricWanted) {
        await ref.read(biometricUnlockServiceProvider).enroll(_passwordController.text);
      }
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setOnboardingComplete(true);
      await settings.setBiometricEnabled(_biometricWanted);

      ref.read(vaultUnlockedProvider.notifier).state = true;
      if (mounted) context.go('/vault');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressDots(current: _page, count: _pageCount),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _IntroPage(
                    icon: Icons.shield_outlined,
                    title: 'Meet Keyla',
                    body: 'You never type or remember a password again. Keyla saves and fills your logins automatically.',
                  ),
                  _IntroPage(
                    icon: Icons.lock_outline,
                    title: 'Only you can read it',
                    body: 'Everything is encrypted on this device with a key only your master password can unlock. Not even Keyla can see your passwords.',
                  ),
                  _CreatePasswordPage(
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    error: _passwordError,
                  ),
                  _BiometricPage(
                    selected: _biometricWanted,
                    onChanged: (v) => setState(() => _biometricWanted = v),
                  ),
                  _RecoveryKitPage(code: _recoveryCode),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _creating ? null : _next,
                  child: _creating
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(_page == _pageCount - 1 ? "I've saved my recovery code" : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.count});
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CreatePasswordPage extends StatelessWidget {
  const _CreatePasswordPage({
    required this.passwordController,
    required this.confirmController,
    required this.error,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Create your master password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This unlocks your vault. There is no way to recover it if you forget it — choose something memorable.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SecretField(controller: passwordController, label: 'Master password', autofocus: true),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: passwordController,
            builder: (context, _) => StrengthMeter(password: passwordController.text),
          ),
          const SizedBox(height: 16),
          SecretField(controller: confirmController, label: 'Confirm master password'),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _BiometricPage extends StatelessWidget {
  const _BiometricPage({required this.selected, required this.onChanged});
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint, size: 72, color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Unlock with biometrics?', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Use Face ID / fingerprint for fast unlocks. Your master password always works too, and biometrics never bypass encryption.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SwitchListTile(
            value: selected,
            onChanged: onChanged,
            title: const Text('Enable biometric unlock'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _RecoveryKitPage extends StatelessWidget {
  const _RecoveryKitPage({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_outlined, size: 64, color: AppColors.warning),
          const SizedBox(height: 20),
          Text('Your recovery kit', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            "Write this down and keep it somewhere safe. Keyla can't reset your master password — this code is your only backup.",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copy code'),
          ),
        ],
      ),
    );
  }
}
