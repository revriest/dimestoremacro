import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dime_store_macro/main.dart';
import 'package:dime_store_macro/screens/onboarding_screen.dart';

void main() {
  testWidgets('Shows onboarding for first-time users', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to BareMacros'), findsOneWidget);
  });

  testWidgets('Shows main app when onboarding is complete', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'has_confirmed_region': true,
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
  });
}
