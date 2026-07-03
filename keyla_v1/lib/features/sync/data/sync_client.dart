import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for the ARIF(KyLa) backup server. Every call here sends only
/// the server-auth secret (never the master password) and, for vault sync,
/// only the already-encrypted vault blob the app produced locally — the
/// server never receives a plaintext credential.
class SyncClient {
  SyncClient({required this.baseUrl});

  /// e.g. https://your-host.example.com/server
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl/$path');

  Future<Map<String, dynamic>> register({
    required String email,
    required String serverAuthSecretBase64,
  }) => _post('arif_kyla_register.php', {
        'email': email,
        'authSecret': serverAuthSecretBase64,
      });

  Future<Map<String, dynamic>> login({
    required String email,
    required String serverAuthSecretBase64,
  }) => _post('arif_kyla_login.php', {
        'email': email,
        'authSecret': serverAuthSecretBase64,
      });

  Future<Map<String, dynamic>> uploadVault({
    required String email,
    required String token,
    required String blobBase64,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required int version,
  }) => _post('arif_kyla_vault_upload.php', {
        'email': email,
        'token': token,
        'blob': blobBase64,
        'kdfSalt': kdfSalt,
        'kdfParams': kdfParams,
        'version': version,
      });

  Future<Map<String, dynamic>?> downloadVault({
    required String email,
    required String token,
  }) async {
    final response = await http.post(
      _uri('arif_kyla_vault_download.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'token': token}),
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
      throw SyncException((decoded['error'] as String?) ?? 'Sync request failed');
    }
    return decoded;
  }
}

class SyncException implements Exception {
  SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}
