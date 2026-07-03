import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vault/presentation/vault_providers.dart';
import '../domain/health_report.dart';

final healthReportProvider = Provider<AsyncValue<HealthReport>>((ref) {
  final credentials = ref.watch(credentialsProvider);
  return credentials.whenData(HealthReport.compute);
});
