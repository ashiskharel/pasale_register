import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/services/service_locator.dart';

void main() {
  setUp(() {
    setupLocator(useFakes: true);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test - starts on LandingScreen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.landingScreen), findsOneWidget);
    expect(find.byKey(AppKeys.roleToggleBar), findsOneWidget);
    expect(find.byKey(AppKeys.continueAsRoleButton), findsOneWidget);
  });
}
