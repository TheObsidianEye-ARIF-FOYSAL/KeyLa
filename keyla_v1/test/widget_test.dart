import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyla_v1/main.dart';

void main() {
  testWidgets('app boots to a MaterialApp without throwing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KeylaApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
