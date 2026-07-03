import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'vault_providers.dart';

class CredentialDetailScreen extends ConsumerStatefulWidget {
  const CredentialDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CredentialDetailScreen> createState() => _CredentialDetailScreenState();
}

class _CredentialDetailScreenState extends ConsumerState<CredentialDetailScreen> {
  bool _passwordRevealed = false;

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(credentialsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/vault/${widget.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final repo = await ref.read(vaultRepositoryProvider.future);
              await repo.deleteCredential(widget.id);
              invalidateVault(ref);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: credentialsAsync.when(
        data: (list) {
          final credential = list.where((c) => c.id == widget.id).firstOrNull;
          if (credential == null) {
            return const Center(child: Text('This credential was deleted.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credential.title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 20),
                _FieldTile(
                  label: 'Username',
                  value: credential.username,
                  onCopy: () async {
                    final repo = await ref.read(vaultRepositoryProvider.future);
                    await repo.markUsed(credential.id);
                    invalidateVault(ref);
                    _copy(context, ref, credential.username);
                  },
                ),
                _FieldTile(
                  label: 'Password',
                  value: _passwordRevealed ? credential.password : '••••••••••••',
                  trailing: IconButton(
                    icon: Icon(_passwordRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () {
                      setState(() => _passwordRevealed = !_passwordRevealed);
                      if (_passwordRevealed) {
                        Future.delayed(const Duration(seconds: 8), () {
                          if (mounted) setState(() => _passwordRevealed = false);
                        });
                      }
                    },
                  ),
                  onCopy: () => _copy(context, ref, credential.password),
                ),
                if (credential.notes?.isNotEmpty ?? false) _FieldTile(label: 'Notes', value: credential.notes!),
                if (credential.category?.isNotEmpty ?? false) _FieldTile(label: 'Category', value: credential.category!),
                const SizedBox(height: 12),
                Text(
                  'Last used: ${credential.lastUsedAt != null ? DateFormat.yMMMd().format(credential.lastUsedAt!) : 'Never'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Updated: ${DateFormat.yMMMd().format(credential.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _copy(BuildContext context, WidgetRef ref, String value) {
    final clearAfter = ref.read(clipboardGuardProvider).copy(value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied — clears in ${clearAfter.inSeconds}s')),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.label, required this.value, this.onCopy, this.trailing});
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(value, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onCopy != null)
              IconButton(icon: Icon(Icons.copy_outlined, color: AppColors.primary), onPressed: onCopy),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
