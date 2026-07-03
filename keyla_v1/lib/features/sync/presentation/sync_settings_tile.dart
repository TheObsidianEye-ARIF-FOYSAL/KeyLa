import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import '../../vault/presentation/vault_providers.dart';
import 'sync_providers.dart';

/// Opt-in "Backup & Sync" row (spec: cloud sync is a v1 non-goal, so this
/// stays off by default and lives entirely behind this toggle). Talks to
/// the ARIF(KyLa) server, which only ever sees the already-encrypted vault
/// blob and a password-derived auth secret — never the master password or
/// plaintext credentials.
class SyncSettingsTile extends ConsumerStatefulWidget {
  const SyncSettingsTile({super.key});

  @override
  ConsumerState<SyncSettingsTile> createState() => _SyncSettingsTileState();
}

class _SyncSettingsTileState extends ConsumerState<SyncSettingsTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(syncServiceProvider);

    return syncAsync.when(
      data: (sync) => FutureBuilder<bool>(
        future: sync.isLinked(),
        builder: (context, snapshot) {
          final linked = snapshot.data ?? false;
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Backup & Sync'),
                subtitle: Text(linked ? 'Linked — encrypted backup only' : 'Off by default. Opt in to back up your encrypted vault.'),
                trailing: linked
                    ? IconButton(icon: const Icon(Icons.link_off), onPressed: () => _unlink(sync))
                    : TextButton(onPressed: () => _showLinkSheet(sync), child: const Text('Set up')),
              ),
              if (linked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _run(() => sync.backupNow(), 'Backup uploaded'),
                          child: const Text('Back up now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _run(() => sync.restoreNow(), 'Vault restored', refreshVault: true),
                          child: const Text('Restore'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _run(Future<void> Function() action, String successMessage, {bool refreshVault = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (refreshVault) invalidateVault(ref);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(dynamic sync) async {
    await sync.unlink();
    setState(() {});
  }

  Future<void> _showLinkSheet(dynamic sync) async {
    final email = TextEditingController();
    final password = TextEditingController();
    var isRegister = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isRegister ? 'Create backup account' : 'Sign in to backup account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Your master password never leaves this device — only a derived secret is sent, and your vault is uploaded already encrypted.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              SecretField(controller: password, label: 'Master password'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _run(() => isRegister
                      ? sync.register(email: email.text.trim(), masterPassword: password.text)
                      : sync.login(email: email.text.trim(), masterPassword: password.text),
                      isRegister ? 'Backup account created' : 'Signed in');
                  setState(() {});
                },
                child: Text(isRegister ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: () => setSheetState(() => isRegister = !isRegister),
                child: Text(isRegister ? 'Already have a backup account? Sign in' : 'New here? Create an account',
                    style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
