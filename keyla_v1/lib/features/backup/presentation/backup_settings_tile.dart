import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/kdf_service.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/user_auth_provider.dart';
import '../../vault/presentation/vault_providers.dart';
import 'backup_providers.dart';

String _encodeExport(Map<String, dynamic> export) => base64Encode(utf8.encode(jsonEncode(export)));

Map<String, dynamic> _decodeExport(String blobBase64) =>
    jsonDecode(utf8.decode(base64Decode(blobBase64))) as Map<String, dynamic>;

KdfParams _kdfParamsFromJson(Map<String, dynamic> json) => KdfParams.fromJson(json);

/// Backs up / restores the vault to the same ARIF(KyLa) account the user is
/// already signed in to (see features/auth) — no separate email/password
/// step. Only the already-encrypted vault export ever leaves the device;
/// the account session token authorizes the call, nothing more.
class BackupSettingsTile extends ConsumerStatefulWidget {
  const BackupSettingsTile({super.key});

  @override
  ConsumerState<BackupSettingsTile> createState() => _BackupSettingsTileState();
}

class _BackupSettingsTileState extends ConsumerState<BackupSettingsTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userAuthProvider).user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backup & Sync'),
          subtitle: Text('Signed in as ${user.name} (${user.phone}) — encrypted backup only'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _backupNow,
                  child: const Text('Back up now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _restoreNow,
                  child: const Text('Restore'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _backupNow() => _run(() async {
        final repo = await ref.read(vaultRepositoryProvider.future);
        final export = await repo.exportForSync();
        final params = await repo.currentKdfParams();
        final client = ref.read(backupClientProvider);
        final user = ref.read(userAuthProvider).user!;
        final token = ref.read(userAuthServiceProvider).token;
        if (token == null) throw StateError('Not signed in');

        await client.uploadVault(
          phone: user.phone,
          token: token,
          blobBase64: _encodeExport(export),
          kdfSalt: params.salt,
          kdfParams: params.toJson(),
          version: 1,
        );
      }, 'Backup uploaded');

  Future<void> _restoreNow() => _run(() async {
        final client = ref.read(backupClientProvider);
        final user = ref.read(userAuthProvider).user!;
        final token = ref.read(userAuthServiceProvider).token;
        if (token == null) throw StateError('Not signed in');

        final response = await client.downloadVault(phone: user.phone, token: token);
        if (response == null) throw StateError('No backup found for this account');

        final repo = await ref.read(vaultRepositoryProvider.future);
        final export = _decodeExport(response['blob'] as String);
        final kdfParams = _kdfParamsFromJson(response['kdfParams'] as Map<String, dynamic>);
        await repo.importFromSync(export, kdfParams);
        invalidateVault(ref);
      }, 'Vault restored');

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
