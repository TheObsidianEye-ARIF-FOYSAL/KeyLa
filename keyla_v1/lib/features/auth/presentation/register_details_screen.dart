import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import 'user_auth_provider.dart';

/// Registration for a phone number not yet known to the server: name +
/// account password. This account password is unrelated to the vault
/// master password created later during onboarding — it only gates the
/// ARIF(KyLa) account/session, never vault encryption.
class RegisterDetailsScreen extends ConsumerStatefulWidget {
  const RegisterDetailsScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends ConsumerState<RegisterDetailsScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = "Passwords don't match");
      return;
    }
    setState(() => _error = null);

    final ok = await ref.read(userAuthProvider.notifier).register(
          phone: widget.phone,
          name: _nameController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _error = ref.read(userAuthProvider).error ?? 'Could not create account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(userAuthProvider).isLoading;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.person_add_alt_1_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 20),
              Text('Create your account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(widget.phone, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              SecretField(controller: _passwordController, label: 'Password (min 6 chars)'),
              const SizedBox(height: 14),
              SecretField(controller: _confirmController, label: 'Confirm password'),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Create account'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
