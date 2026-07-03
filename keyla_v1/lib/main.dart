import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: KeylaApp()));
}

class KeylaApp extends ConsumerStatefulWidget {
  const KeylaApp({super.key});

  @override
  ConsumerState<KeylaApp> createState() => _KeylaAppState();
}

class _KeylaAppState extends ConsumerState<KeylaApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vaultUnlockedProvider, (previous, unlocked) {
      final autoLock = ref.read(autoLockControllerProvider);
      if (unlocked) {
        autoLock.arm();
      } else {
        autoLock.disarm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);
    final themeMode = settingsAsync.maybeWhen(data: (s) => s.themeMode, orElse: () => ThemeMode.system);

    return Listener(
      onPointerDown: (_) => ref.read(autoLockControllerProvider).registerActivity(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp.router(
        title: 'Keyla',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
