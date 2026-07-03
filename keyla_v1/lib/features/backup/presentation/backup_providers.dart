import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server_config.dart';
import '../data/backup_client.dart';

final backupClientProvider = Provider<BackupClient>((ref) => BackupClient(baseUrl: kServerBaseUrl));
