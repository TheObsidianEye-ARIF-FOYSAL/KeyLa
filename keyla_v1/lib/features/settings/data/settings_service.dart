import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive app preferences only. Nothing here is ever a secret —
/// vault contents and keys live exclusively in the encrypted DB / secure
/// storage, never in SharedPreferences.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async {
    return SettingsService(await SharedPreferences.getInstance());
  }

  static const _kAutoLockSeconds = 'auto_lock_seconds';
  static const _kClipboardSeconds = 'clipboard_clear_seconds';
  static const _kThemeMode = 'theme_mode';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kSyncEnabled = 'sync_enabled';
  static const _kOnboardingComplete = 'onboarding_complete';

  Duration get autoLockTimeout =>
      Duration(seconds: _prefs.getInt(_kAutoLockSeconds) ?? 60);
  Future<void> setAutoLockTimeout(Duration d) =>
      _prefs.setInt(_kAutoLockSeconds, d.inSeconds);

  Duration get clipboardClearTimeout =>
      Duration(seconds: _prefs.getInt(_kClipboardSeconds) ?? 30);
  Future<void> setClipboardClearTimeout(Duration d) =>
      _prefs.setInt(_kClipboardSeconds, d.inSeconds);

  ThemeMode get themeMode {
    switch (_prefs.getString(_kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool v) => _prefs.setBool(_kBiometricEnabled, v);

  bool get syncEnabled => _prefs.getBool(_kSyncEnabled) ?? false;
  Future<void> setSyncEnabled(bool v) => _prefs.setBool(_kSyncEnabled, v);

  bool get onboardingComplete => _prefs.getBool(_kOnboardingComplete) ?? false;
  Future<void> setOnboardingComplete(bool v) => _prefs.setBool(_kOnboardingComplete, v);
}
