import 'package:committee_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:committee_app/l10n/app_localizations.dart';

void main() {
  testWidgets('LoginScreen renders all necessary fields',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    // Verify presence of title
    expect(find.text('Host Login'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);

    // Verify text fields
    expect(find.byType(TextFormField), findsNWidgets(2)); // Email and Password
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify buttons
    expect(find.byType(ElevatedButton), findsOneWidget); // Sign In button
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('LoginScreen toggles to Sign Up mode',
      (WidgetTester tester) async {
    // Increase surface height to ensure all elements are reachable
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );

    // Find and tap "Sign Up" text
    final signUpText = find.text('Sign Up');
    expect(signUpText, findsOneWidget);

    // Ensure the widget is visible before tapping
    await tester.ensureVisible(signUpText);
    await tester.pumpAndSettle();

    await tester.tap(signUpText);
    await tester.pumpAndSettle();

    // Verify mode changed
    expect(find.text('Create Account'), findsAtLeastNWidgets(1));
    expect(find.text('Full Name'), findsOneWidget);
    expect(
        find.byType(TextFormField), findsNWidgets(3)); // Name, Email, Password
  });
}
