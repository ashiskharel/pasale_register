import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/main.dart';
import 'package:pasale_register/models/user_role.dart';
import 'package:pasale_register/services/cart_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SessionKeys.isLoggedIn: true,
      SessionKeys.role: UserRole.storeOwner.name,
      SessionKeys.phone: '9801112233',
      SessionKeys.trainingDone: true,
      SessionKeys.storeId: 's1',
      SessionKeys.deviceId: 'd1',
      SessionKeys.isActivated: true,
      SessionKeys.storeName: 'Test Store',
    });
    setupLocator(useFakes: true);
  });

  testWidgets('loose open item form adds to cart without barcode',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.storeOwnerShell), findsOneWidget);
    expect(find.byKey(AppKeys.addOpenItemButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.addOpenItemButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.registerUnknownProductDialog), findsOneWidget);
    expect(find.text('Open / loose item'), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.registerProductNameInput),
      'Tomatoes 1kg',
    );
    await tester.enterText(
      find.byKey(AppKeys.registerProductPriceInput),
      '120',
    );
    await tester.tap(find.byKey(AppKeys.registerProductSaveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final cart = locator<CartService>();
    expect(cart.items.length, 1);
    expect(cart.items.first.product.name, 'Tomatoes 1kg');
    expect(cart.items.first.product.sellingPrice, 120);
    expect(cart.items.first.product.barcode, startsWith('OPEN_'));
  });
}
