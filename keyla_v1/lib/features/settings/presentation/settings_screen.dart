import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/secret_field.dart';
import '../../auth/presentation/user_auth_provider.dart';
import '../../backup/presentation/backup_settings_tile.dart';
import '../../onboarding/data/recovery_kit.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) => ListView(
          children: [
            const _SectionHeader('Account'),
            _AccountSection(),
            const _SectionHeader('Security'),
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change master password'),
              onTap: () => _showChangePasswordSheet(context),
            ),
            FutureBuilder<bool>(
              future: ref.read(biometricUnlockServiceProvider).isDeviceSupported(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric unlock'),
                  value: settings.biometricEnabled,
                  onChanged: (v) => _toggleBiometric(v),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Auto-lock timeout'),
              subtitle: Text('${settings.autoLockTimeout.inSeconds}s of inactivity'),
              onTap: () => _pickDuration(
                title: 'Auto-lock after',
                current: settings.autoLockTimeout,
                options: const [30, 60, 120, 300],
                onPicked: (d) async {
                  await settings.setAutoLockTimeout(d);
                  ref.read(autoLockControllerProvider).timeout = d;
                  setState(() {});
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_off_outlined),
              title: const Text('Clipboard auto-clear'),
              subtitle: Text('${settings.clipboardClearTimeout.inSeconds}s after copy'),
              onTap: () => _pickDuration(
                title: 'Clear clipboard after',
                current: settings.clipboardClearTimeout,
                options: const [15, 30, 60, 120],
                onPicked: (d) async {
                  await settings.setClipboardClearTimeout(d);
                  setState(() {});
                },
              ),
            ),
            const _SectionHeader('Appearance'),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(settings.themeMode)),
              onTap: () => _pickTheme(settings),
            ),
            const _SectionHeader('Backup'),
            const SyncSettingsTile(),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('View recovery kit'),
              subtitle: const Text('Generates a new printable code'),
              onTap: () => _showRecoveryKit(context),
            ),
            const _SectionHeader('Autofill'),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: Theme.of(context).disabledColor),
              title: const Text('OS Autofill'),
              subtitle: const Text('Coming soon — Android Autofill & iOS Credential Provider'),
              enabled: false,
            ),
            const _SectionHeader('Danger zone'),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: AppColors.danger),
              title: Text('Delete all data', style: TextStyle(color: AppColors.danger)),
              onTap: () => _confirmDeleteAll(context),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Follow system',
      };

  Future<void> _pickTheme(dynamic settings) async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((m) {
            return ListTile(title: Text(_themeLabel(m)), onTap: () => Navigator.pop(context, m));
          }).toList(),
        ),
      ),
    );
    if (mode != null) {
      await settings.setThemeMode(mode);
      ref.invalidate(settingsServiceProvider);
    }
  }

  Future<void> _pickDuration({
    required String title,
    required Duration current,
    required List<int> options,
    required ValueChanged<Duration> onPicked,
  }) async {
    final seconds = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ...options.map((s) => ListTile(title: Text('${s}s'), onTap: () => Navigator.pop(context, s))),
          ],
        ),
      ),
    );
    if (seconds != null) onPicked(Duration(seconds: seconds));
  }

  Future<void> _toggleBiometric(bool enable) async {
    final biometrics = ref.read(biometricUnlockServiceProvider);
    final settings = await ref.read(settingsServiceProvider.future);
    if (!enable) {
      await biometrics.disable();
      await settings.setBiometricEnabled(false);
      setState(() {});
      return;
    }
    final password = await _promptMasterPassword();
    if (password == null) return;
    await biometrics.enroll(password);
    await settings.setBiometricEnabled(true);
    setState(() {});
  }

  Future<String?> _promptMasterPassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm master password'),
        content: SecretField(controller: controller, label: 'Master password', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Confirm')),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  Future<void> _showChangePasswordSheet(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change master password', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SecretField(controller: current, label: 'Current master password'),
            const SizedBox(height: 12),
            SecretField(controller: next, label: 'New master password'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final repo = await ref.read(vaultRepositoryProvider.future);
                try {
                  await repo.unlock(current.text);
                  await repo.changeMasterPassword(next.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master password updated')));
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect')));
                  }
                }
              },
              child: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecoveryKit(BuildContext context) async {
    final code = RecoveryKit.generate();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your recovery kit'),
        content: SelectableText(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('This permanently deletes your entire vault from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(vaultRepositoryProvider.future);
      await repo.deleteEverything();
      await ref.read(biometricUnlockServiceProvider).disable();
      ref.invalidate(vaultRepositoryProvider);
      ref.read(vaultUnlockedProvider.notifier).state = false;
      if (context.mounted) context.go('/');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6),
      ),
    );
  }
}
