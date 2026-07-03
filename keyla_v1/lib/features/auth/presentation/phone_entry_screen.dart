import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import 'login_password_screen.dart';
import 'register_details_screen.dart';
import 'user_auth_provider.dart';

/// First step of the account gate: collect a phone number, then route to
/// either the login or register screen depending on whether the ARIF(KyLa)
/// server already has an account for it — mirrors MedRemind's
/// PhoneScreen -> checkPhoneExists -> LoginPasswordScreen/RegisterDetailsScreen flow.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11) return 'Enter an 11-digit phone number';
    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final exists = await ref.read(userAuthProvider.notifier).checkPhoneExists(phone);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => exists ? LoginPasswordScreen(phone: phone) : RegisterDetailsScreen(phone: phone),
      ));
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(userAuthProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not reach the server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(userAuthProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone_iphone_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Sign in to Keyla', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Your phone number identifies your account. It never touches your vault encryption.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: _validate,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _continue,
                  child: isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
