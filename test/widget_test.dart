import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorivo/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders email/password fields and a submit button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    // LoginController is an AsyncNotifier: its initial state is
    // AsyncLoading until build()'s Future resolves, so the submit
    // button briefly shows a spinner instead of "Log in" — pump once
    // more to let that resolve before asserting on the button's label.
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    // Fields are AuthField widgets labelled 'Email' / 'Password'.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);

    // Submitting an empty form should surface validation errors, not crash.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
