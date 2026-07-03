import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/sync_client.dart';
import '../data/sync_service.dart';

/// Base URL of the ARIF(KyLa) PHP server, e.g.
/// 'https://your-host.example.com/keyla_v1/server'. Left overridable so the
/// app doesn't hardcode a production endpoint.
final syncBaseUrlProvider = Provider<String>((ref) => 'https://example.com/keyla_v1/server');

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final repo = await ref.watch(vaultRepositoryProvider.future);
  final client = SyncClient(baseUrl: ref.watch(syncBaseUrlProvider));
  return SyncService(client: client, repository: repo);
});
