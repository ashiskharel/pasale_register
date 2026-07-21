import 'package:flutter_test/flutter_test.dart';
import 'package:pasale_register/models/cart_item.dart';
import 'package:pasale_register/models/product.dart';
import 'package:pasale_register/models/store_invoice.dart';
import 'package:pasale_register/services/invoice_history_service.dart';
import 'package:pasale_register/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    setupLocator(useFakes: true);
  });

  test('invoice totals cash + credit + grand', () {
    final list = [
      StoreInvoice(
        id: '1',
        createdAt: DateTime(2026, 1, 1),
        total: 100,
        payment: InvoicePayment.cash,
        source: InvoiceSource.cart,
      ),
      StoreInvoice(
        id: '2',
        createdAt: DateTime(2026, 1, 2),
        total: 50,
        payment: InvoicePayment.credit,
        source: InvoiceSource.manual,
      ),
      StoreInvoice(
        id: '3',
        createdAt: DateTime(2026, 1, 3),
        total: 25,
        payment: InvoicePayment.cash,
        source: InvoiceSource.cart,
      ),
    ];
    final t = list.totals;
    expect(t.cashTotal, 125);
    expect(t.creditTotal, 50);
    expect(t.grandTotal, 175);
    expect(t.count, 3);
  });

  test('history persists cart and manual invoices', () async {
    final history = locator<InvoiceHistoryService>();
    await history.load();

    final product = Product(
      id: 'p1',
      name: 'Tea',
      barcode: 'p1',
      sellingPrice: 40,
      costPrice: 20,
      markup: 100,
    );
    await history.add(
      StoreInvoice.fromCart(
        cart: [CartItem(product: product, quantity: 2)],
        total: 80,
        payment: InvoicePayment.cash,
        customerPhone: '9801112233',
        customerName: 'Ram',
        storeId: 's1',
      ),
    );
    await history.add(
      StoreInvoice.fromManual(
        date: DateTime(2026, 7, 1),
        total: 500,
        payment: InvoicePayment.credit,
        customerPhone: '9801234567',
        customerName: 'Sita',
        storeId: 's1',
        notes: 'bulk',
      ),
    );

    expect(history.invoices.length, 2);
    expect(history.totals.cashTotal, 80);
    expect(history.totals.creditTotal, 500);
    expect(history.totals.grandTotal, 580);
    expect(history.customers.length, 2);
    expect(
      history.recentCustomers(limit: 10).first.phone,
      anyOf('9801112233', '9801234567'),
    );

    // Reload from prefs
    final again = InvoiceHistoryService();
    await again.load(storeId: 's1');
    expect(again.invoices.length, greaterThanOrEqualTo(2));
    expect(again.totals.grandTotal, greaterThanOrEqualTo(580));
  });
}
