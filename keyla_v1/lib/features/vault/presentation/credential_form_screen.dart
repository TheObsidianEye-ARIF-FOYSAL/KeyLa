import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/secret_field.dart';
import '../../generator/presentation/generator_sheet.dart';
import '../domain/credential.dart';
import 'vault_providers.dart';

/// Add (editId == null) or edit an existing credential.
class CredentialFormScreen extends ConsumerStatefulWidget {
  const CredentialFormScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<CredentialFormScreen> createState() => _CredentialFormScreenState();
}

class _CredentialFormScreenState extends ConsumerState<CredentialFormScreen> {
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  Credential? _existing;
  late final Future<void> _loadFuture = _loadIfEditing();

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadIfEditing() async {
    if (_loaded || widget.editId == null) {
      _loaded = true;
      return;
    }
    final list = await ref.read(credentialsProvider.future);
    final match = list.where((c) => c.id == widget.editId).toList();
    if (match.isNotEmpty) {
      _existing = match.first;
      _titleController.text = _existing!.title;
      _usernameController.text = _existing!.username;
      _passwordController.text = _existing!.password;
      _notesController.text = _existing!.notes ?? '';
      _categoryController.text = _existing!.category ?? '';
    }
    _loaded = true;
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(vaultRepositoryProvider.future);
      if (_existing != null) {
        await repo.updateCredential(_existing!.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text,
          password: _passwordController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          category: _categoryController.text.isEmpty ? null : _categoryController.text,
        ));
      } else {
        await repo.addCredential(
          title: _titleController.text.trim(),
          username: _usernameController.text,
          password: _passwordController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          category: _categoryController.text.isEmpty ? null : _categoryController.text,
        );
      }
      invalidateVault(ref);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openGenerator() async {
    final generated = await showGeneratorSheet(context);
    if (generated != null) {
      _passwordController.text = generated;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text(_existing != null ? 'Edit password' : 'Add password')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title (e.g. Netflix)'),
                  autofocus: _existing == null,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username or email'),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SecretField(controller: _passwordController, label: 'Password')),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openGenerator,
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: const Text('Generate'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category (optional)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
