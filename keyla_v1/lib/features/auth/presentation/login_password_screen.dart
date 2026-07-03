import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import 'user_auth_provider.dart';

/// Second step for an existing phone number: password entry, verified
/// server-side by arif_kyla_login.php against the stored password hash.
class LoginPasswordScreen extends ConsumerStatefulWidget {
  const LoginPasswordScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends ConsumerState<LoginPasswordScreen> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final ok = await ref.read(userAuthProvider.notifier).login(
          phone: widget.phone,
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      // The app's flow gate watches userAuthProvider and advances automatically.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = ref.read(userAuthProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(userAuthProvider).isLoading;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 20),
              Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(widget.phone, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              SecretField(controller: _passwordController, label: 'Password', autofocus: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
