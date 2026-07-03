import 'package:flutter/services.dart';

/// Bridges to native code to block screenshots/screen-recording on
/// sensitive screens (Android `FLAG_SECURE`) and to blur the app preview in
/// the OS app switcher (spec §5). The iOS side additionally installs a blur
/// overlay on `willResignActive` in AppDelegate.
///
/// Requires the native handlers registered in `MainActivity`/`AppDelegate`
/// (see android/app/.../MainActivity.kt and ios/Runner/AppDelegate.swift).
class ScreenPrivacy {
  ScreenPrivacy._();

  static const _channel = MethodChannel('keyla/screen_privacy');

  /// Enables FLAG_SECURE (Android) / prepares the obscuring overlay (iOS).
  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } on MissingPluginException {
      // No-op on platforms without the native handler wired up yet (e.g. web/desktop dev runs).
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } on MissingPluginException {
      // No-op — see [enable].
    }
  }
}
