import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorivo/features/auth/presentation/splash_screen.dart';

void main() {
  testWidgets('SplashScreen builds, animates, and shows the brand text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Advance through the one-shot intro timeline; the painters (scissors,
    // tools) and gradients must render every frame without throwing.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('shorivo'), findsOneWidget);
    expect(find.text('BOOK YOUR CHAIR'), findsOneWidget);
    expect(find.text('BOOKING FOR PROFESSIONALS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
