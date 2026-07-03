import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../domain/credential.dart';

/// Bumped after any mutation to force [credentialsProvider] to reload.
final vaultRefreshTickProvider = StateProvider<int>((ref) => 0);

final credentialsProvider = FutureProvider<List<Credential>>((ref) async {
  ref.watch(vaultRefreshTickProvider);
  final repo = await ref.watch(vaultRepositoryProvider.future);
  if (!repo.isUnlocked) return const [];
  return repo.listCredentials();
});

final vaultSearchQueryProvider = StateProvider<String>((ref) => '');
final vaultShowFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

final filteredCredentialsProvider = Provider<AsyncValue<List<Credential>>>((ref) {
  final query = ref.watch(vaultSearchQueryProvider).trim().toLowerCase();
  final favoritesOnly = ref.watch(vaultShowFavoritesOnlyProvider);
  final async = ref.watch(credentialsProvider);
  return async.whenData((list) {
    return list.where((c) {
      if (favoritesOnly && !c.isFavorite) return false;
      if (query.isEmpty) return true;
      return c.title.toLowerCase().contains(query) || c.username.toLowerCase().contains(query);
    }).toList();
  });
});

void invalidateVault(WidgetRef ref) => ref.read(vaultRefreshTickProvider.notifier).state++;
