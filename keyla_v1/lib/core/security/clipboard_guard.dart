import 'dart:async';

import 'package:flutter/services.dart';

/// Copies a secret to the clipboard and schedules an auto-clear so plaintext
/// passwords never linger in clipboard history (spec §5 Clipboard).
class ClipboardGuard {
  ClipboardGuard({this.clearAfter = const Duration(seconds: 30)});

  final Duration clearAfter;
  Timer? _pendingClear;
  String? _lastCopiedValue;

  /// Copies [value] and arms the auto-clear timer. Returns the delay so
  /// callers can surface "Copied — clears in Ns" feedback.
  Duration copy(String value) {
    _pendingClear?.cancel();
    _lastCopiedValue = value;
    Clipboard.setData(ClipboardData(text: value));
    _pendingClear = Timer(clearAfter, _clearIfUnchanged);
    return clearAfter;
  }

  Future<void> _clearIfUnchanged() async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == _lastCopiedValue) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    _lastCopiedValue = null;
  }

  void dispose() {
    _pendingClear?.cancel();
  }
}
