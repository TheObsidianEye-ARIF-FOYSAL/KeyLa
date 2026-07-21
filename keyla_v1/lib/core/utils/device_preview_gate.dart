import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// True only for the web build running in a desktop/laptop browser.
///
/// `med_remind_v2` wraps its web demo in `DevicePreview` so the app can be
/// viewed inside a phone frame from any browser — but skips it on phones,
/// where the app should just fill the screen like a native app.
///
/// Unlike MedRemind's `dart:html`-based detector, this reads the same signals
/// straight out of `dart:ui`: on web, [defaultTargetPlatform] is already
/// derived from the user agent, and the implicit view gives the viewport
/// width. That keeps it free of deprecated web-only imports and needs no
/// conditional-import stub.
final bool devicePreviewEnabled = kIsWeb && !_isMobileWebBrowser();

bool _isMobileWebBrowser() {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return true;
  }
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return false;
  return view.physicalSize.width / view.devicePixelRatio < 900;
}
