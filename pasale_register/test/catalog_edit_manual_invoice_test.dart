import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/constants/keys.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/screens/manual_invoice_screen.dart';
import 'package:pasale_register/services/fakes/fake_firestore_service.dart';
import 'package:pasale_register/services/fakes/fake_sharing_service.dart';
import 'package:pasale_register/services/firestore_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:pasale_register/services/sharing_service.dart';
import 'package:pasale_register/utils/bill_formatter.dart';
import 'package:pasale_register/widgets/register_product_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'storeId': 's1',
      'storeName': 'Test Store',
    });
    setupLocator(useFakes: true);
  });

  test('manual invoice text includes paid/credit and total', () {
    final paid = BillFormatter.generateManualInvoice(
      storeName: 'Shop',
      date: DateTime(2026, 7, 13),
      totalPrice: 500,
      customerPhone: '9801112233',
      isPaid: true,
      notes: 'bulk',
    );
    expect(paid, contains('PAID'));
    expect(paid, contains('500.00'));
    expect(paid, contains('bulk'));

    final credit = BillFormatter.generateManualInvoice(
      storeName: 'Shop',
      date: DateTime(2026, 7, 13),
      totalPrice: 200,
      customerPhone: '9801112233',
      isPaid: false,
    );
    expect(credit, contains('CREDIT'));
    expect(credit, contains('TOTAL DUE'));
  });

  test('fake firestore stream includes store product', () async {
    final fs = locator<FirestoreService>() as FakeFirestoreService;
    await fs.saveProduct(
      Product(
        id: 'B1',
        name: 'Soap',
        barcode: 'B1',
        sellingPrice: 40,
        costPrice: 30,
        markup: 33,
        storeId: 's1',
      ),
      storeId: 's1',
    );
    final list = await fs.streamCatalog(storeId: 's1').first;
    expect(list.any((p) => p.barcode == 'B1' && p.name == 'Soap'), isTrue);
  });

  testWidgets('edit product dialog prefills and saves updates', (tester) async {
    final fs = locator<FirestoreService>() as FakeFirestoreService;
    final product = Product(
      id: 'B1',
      name: 'Soap',
      barcode: 'B1',
      sellingPrice: 40,
      costPrice: 30,
      markup: 33,
      storeId: 's1',
      notes: 'bar',
    );
    await fs.saveProduct(product, storeId: 's1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('openEdit'),
                onPressed: () {
                  showRegisterProductDialog(
                    context: context,
                    kind: RegisterProductKind.edit,
                    storeId: 's1',
                    existingProduct: product,
                  );
                },
                child: const Text('Edit'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openEdit')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.registerUnknownProductDialog), findsOneWidget);
    expect(find.text('Edit product'), findsOneWidget);
    expect(find.text('Barcode: B1'), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.registerProductNameInput),
      'Soap XL',
    );
    await tester.enterText(
      find.byKey(AppKeys.registerProductPriceInput),
      '55',
    );
    await tester.tap(find.byKey(AppKeys.registerProductSaveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    final saved = await fs.getProduct('B1', storeId: 's1');
    expect(saved?.name, 'Soap XL');
    expect(saved?.sellingPrice, 55);
    expect(saved?.barcode, 'B1');
  });

  testWidgets('manual invoice form sends paid invoice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ManualInvoiceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.manualInvoiceScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.manualInvoiceTotalInput),
      '999',
    );
    await tester.enterText(
      find.byKey(AppKeys.manualInvoicePhoneInput),
      '9801234567',
    );

    final send = find.byKey(AppKeys.manualInvoiceSendButton);
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    await tester.pumpAndSettle();

    final share = locator<SharingService>() as FakeSharingService;
    expect(share.shareCount, 1);
    expect(share.lastSharedPhoneNumber, '9801234567');
    expect(share.lastSharedReceiptText, contains('999.00'));
    expect(share.lastSharedReceiptText, contains('PAID'));
  });
}
