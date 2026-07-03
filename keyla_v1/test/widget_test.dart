import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyla_v1/core/theme/app_theme.dart';

// A full boot of KeylaApp needs the native libsodium/SQLCipher plugins,
// which `flutter test`'s VM host can't load (see test/core/crypto_test.dart
// for the same constraint) — that path is instead verified by a real
// `flutter build apk` and a device/emulator run. This test just sanity
// checks the theme builds without throwing.
void main() {
  testWidgets('light and dark themes build without throwing', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const SizedBox()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const SizedBox()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
