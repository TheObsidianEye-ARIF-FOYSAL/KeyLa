import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/server_config.dart';
import '../data/backup_client.dart';

final backupClientProvider = Provider<BackupClient>((ref) => BackupClient(baseUrl: kServerBaseUrl));

/// Uploads the current vault export to the signed-in account. Throws if
/// there's no vault yet or no active account session.
final backupUploadProvider = Provider((ref) {
  return () async {
    final repo = await ref.read(vaultRepositoryProvider.future);
    final export = await repo.exportForSync();
    final params = await repo.currentKdfParams();
    return {'export': export, 'params': params};
  };
});
