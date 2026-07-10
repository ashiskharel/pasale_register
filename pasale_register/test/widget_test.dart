import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/screens/activation_screen.dart';

void main() {
  testWidgets('App smoke test - starts on ActivationScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify ActivationScreen is shown
    expect(find.byType(ActivationScreen), findsOneWidget);
  });
}
