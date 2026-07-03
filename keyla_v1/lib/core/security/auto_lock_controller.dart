import 'dart:async';

import 'package:flutter/widgets.dart';

/// Locks the vault after [timeout] of inactivity, or immediately when the
/// app is backgrounded (spec §5: "Auto-lock the vault after inactivity
/// (DEFAULT: 60s) and on app backgrounding").
class AutoLockController with WidgetsBindingObserver {
  AutoLockController({
    required this.onLock,
    this.timeout = const Duration(seconds: 60),
  });

  final VoidCallback onLock;
  Duration timeout;

  Timer? _timer;
  bool _armed = false;

  void arm() {
    _armed = true;
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  void disarm() {
    _armed = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Call on any user interaction (tap, scroll, keystroke) to postpone lock.
  void registerActivity() {
    if (_armed) _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(timeout, onLock);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_armed) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _timer?.cancel();
      onLock();
    }
  }
}
