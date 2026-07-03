import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for the vault-blob endpoints of the ARIF(KyLa) server. Account
/// register/login/session lives in UserAuthService — this only ever sends
/// the phone+session token (never a password) plus the vault export, which
/// is already client-side ciphertext by the time it reaches here.
class BackupClient {
  BackupClient({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl/$path');

  Future<Map<String, dynamic>> uploadVault({
    required String phone,
    required String token,
    required String blobBase64,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required int version,
  }) => _post('arif_kyla_vault_upload.php', {
        'phone': phone,
        'token': token,
        'blob': blobBase64,
        'kdfSalt': kdfSalt,
        'kdfParams': kdfParams,
        'version': version,
      });

  Future<Map<String, dynamic>?> downloadVault({
    required String phone,
    required String token,
  }) async {
    final response = await http.post(
      _uri('arif_kyla_vault_download.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'token': token}),
    );
    if (response.statusCode == 404) return null;
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw BackupException((decoded['error'] as String?) ?? 'Backup request failed');
    }
    return decoded;
  }
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}
