import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_user.dart';
import '../../../core/server_config.dart';

const _kPhoneKey = 'keyla_session_phone';
const _kTokenKey = 'keyla_session_token';

/// Phone+password identity backed by a small PHP+SQLite API (the ARIF(KyLa)
/// server) — structured identically to med_remind_v2's
/// `UserAuthService`/`medremind_*.php`. No Firebase, no OTP/carrier billing:
/// the server hashes/verifies passwords with PHP's password_hash /
/// password_verify and issues an opaque session token, cached locally via
/// SharedPreferences.
///
/// This is Keyla's *account* gate only — it never touches the vault's
/// master password or its Argon2id-derived encryption key (see
/// VaultRepository / KdfService), which remain entirely local and
/// zero-knowledge.
class UserAuthService {
  final String _baseUrl;

  String? _token;

  UserAuthService({String? baseUrl}) : _baseUrl = _sanitize(baseUrl ?? _kDefaultBaseUrl);

  /// Reads a previously persisted session (if any) so the app can restore
  /// it on start. Returns the phone number to restore, or null.
  Future<String?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_kPhoneKey);
    final token = prefs.getString(_kTokenKey);
    if (phone == null || token == null) return null;
    _token = token;
    return phone;
  }

  Future<void> _persistSession(String phone, String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhoneKey, phone);
    await prefs.setString(_kTokenKey, token);
  }

  Future<void> _clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhoneKey);
    await prefs.remove(_kTokenKey);
  }

  String? get token => _token;

  Future<bool> checkPhoneExists(String phone) async {
    final map = await _post('arif_kyla_check_phone.php', {'phone': phone});
    return map['exists'] == true;
  }

  Future<AppUser> register({
    required String phone,
    required String name,
    required String password,
  }) async {
    final map = await _post('arif_kyla_register.php', {
      'phone': phone,
      'name': name,
      'password': password,
    });
    await _persistSession(map['phone'] as String, map['token'] as String);
    return _userFromMap(map);
  }

  Future<AppUser> login({required String phone, required String password}) async {
    final map = await _post('arif_kyla_login.php', {
      'phone': phone,
      'password': password,
    });
    await _persistSession(map['phone'] as String, map['token'] as String);
    return _userFromMap(map);
  }

  Future<void> signOut() => _clearSession();

  Future<void> deleteAccount(String phone) async {
    final token = _token;
    if (token == null) throw Exception('Not signed in');
    await _post('arif_kyla_delete_account.php', {'phone': phone, 'token': token});
    await _clearSession();
  }

  /// Change password for the current session (user already knows their
  /// current password). Server rotates the session token; we persist the
  /// new one so this device stays signed in.
  Future<void> changePassword({
    required String phone,
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = _token;
    if (token == null) throw Exception('Not signed in');
    final map = await _post('arif_kyla_change_password.php', {
      'phone': phone,
      'token': token,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    await _persistSession(phone, map['token'] as String);
  }

  Future<AppUser?> fetchProfile(String phone) async {
    final token = _token;
    if (token == null) return null;
    try {
      final map = await _post('arif_kyla_profile.php', {'phone': phone, 'token': token});
      return _userFromMap(map);
    } catch (_) {
      return null;
    }
  }

  AppUser _userFromMap(Map<String, dynamic> map) => AppUser(
        phone: map['phone'] as String,
        name: (map['name'] ?? '').toString(),
      );

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    final map = _json(response.body);
    if (response.statusCode != 200) {
      throw Exception((map['error'] ?? 'Request failed (${response.statusCode})').toString());
    }
    return map;
  }

  Map<String, dynamic> _json(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return data;
      throw const FormatException();
    } catch (_) {
      throw Exception('Invalid server response');
    }
  }

  String mapError(Object e) => e.toString().replaceFirst('Exception: ', '');

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
