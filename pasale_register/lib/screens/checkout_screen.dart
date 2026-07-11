import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../models/cart_item.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';
import '../services/scanner_service.dart';
import '../services/sharing_service.dart';
import '../services/cart_service.dart';
import '../utils/bill_formatter.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _manualBarcodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPaid = true; // true = Paid, false = Credit
  String _status = '';
  bool _isScanning = false;
  String _storeName = 'Pasale';

  List<CartItem> get _cart => locator<CartService>().items;

  double get _totalPrice => locator<CartService>().totalPrice;

  bool get _checkedOut => locator<CartService>().checkoutCompleted;
  set _checkedOut(bool value) => locator<CartService>().checkoutCompleted = value;

  @override
  void initState() {
    super.initState();
    locator<CartService>().addListener(_onCartChanged);
    _loadStoreName();
  }

  @override
  void dispose() {
    locator<CartService>().removeListener(_onCartChanged);
    _manualBarcodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {
        if (_status == 'Checkout complete' && !_checkedOut) {
          _status = '';
        }
      });
    }
  }

  Future<void> _loadStoreName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('storeName');
      if (name != null && name.isNotEmpty) {
        setState(() {
          _storeName = name;
        });
      }
    } catch (_) {}
  }

  Future<void> _addBarcodeToCart(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _status = 'Error: Barcode is empty';
      });
      return;
    }
    try {
      final product = await locator<FirestoreService>().getProduct(trimmed);
      if (product != null) {
        final existingIndex = _cart.indexWhere((item) => item.product.barcode == trimmed);
        if (existingIndex >= 0 && _cart[existingIndex].quantity >= 999) {
          setState(() {
            _status = 'Error: Max quantity reached';
          });
          return;
        }

        locator<CartService>().addProduct(product);

        setState(() {
          _status = 'Added ${product.name} to cart';
        });

        try {
          await locator<ScannerService>().triggerFeedback();
        } catch (e) {
          setState(() {
            _status = 'Feedback error: $e';
          });
        }
      } else {
        setState(() {
          _status = 'Product not found: $trimmed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error loading product: $e';
      });
    }
  }

  Future<void> _scanBarcode() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
    });
    try {
      while (_isScanning) {
        final barcode = await locator<ScannerService>().scan();
        if (!_isScanning) {
          break;
        }
        if (barcode != null) {
          final trimmed = barcode.trim();
          if (trimmed.isEmpty) {
            setState(() {
              _status = 'Scan cancelled';
            });
          } else {
            await _addBarcodeToCart(trimmed);
          }
        } else {
          setState(() {
            _status = 'Scan cancelled';
          });
        }
        // Small delay to prevent tight spin loop
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      setState(() {
        _status = 'Scan error: $e';
        _isScanning = false;
      });
    }
  }

  void _checkout() {
    if (_cart.isEmpty) {
      setState(() {
        _status = 'Cart is empty';
      });
      return;
    }
    setState(() {
      _checkedOut = true;
      _status = 'Checkout complete';
    });
  }

  Future<void> _shareReceipt() async {
    if (_cart.isEmpty) {
      setState(() {
        _status = 'Error: Cart is empty, cannot share receipt';
      });
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _status = 'Enter phone number first';
      });
      return;
    }
    if (!BillFormatter.isValidNepaliPhoneNumber(phone)) {
      setState(() {
        _status = 'Error: Invalid phone number format';
      });
      return;
    }

    final receiptText = BillFormatter.generateReceipt(
      cart: _cart,
      totalPrice: _totalPrice,
      isPaid: _isPaid,
      checkedOut: _checkedOut,
      storeName: _storeName,
    );

    try {
      await locator<SharingService>().shareReceipt(receiptText, phone);
      setState(() {
        _status = 'Receipt shared with $phone';
      });
    } catch (e) {
      setState(() {
        _status = 'Share error: $e';
      });
    }
  }

  Widget _buildCartList() {
    return ListView.builder(
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        return ListTile(
          key: ValueKey('cart_item_${item.product.barcode}'),
          title: Text(item.product.name),
          subtitle: Text('Rs. ${item.product.sellingPrice.toStringAsFixed(2)} x ${item.quantity}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('decrement_qty_${item.product.barcode}'),
                icon: const Icon(Icons.remove),
                onPressed: () {
                  locator<CartService>().decrementQuantity(item.product.barcode);
                },
              ),
              Text('${item.quantity}'),
              IconButton(
                key: ValueKey('increment_qty_${item.product.barcode}'),
                icon: const Icon(Icons.add),
                onPressed: () {
                  final success = locator<CartService>().incrementQuantity(item.product.barcode);
                  if (!success) {
                    setState(() {
                      _status = 'Error: Max quantity reached';
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Cart')),
      body: _isScanning
          ? Row(
               children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          key: const Key('scanPreview'),
                          width: double.infinity,
                          margin: const EdgeInsets.all(8.0),
                          color: Colors.black,
                          clipBehavior: Clip.hardEdge,
                          child: locator<ScannerService>().buildScannerWidget(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _status,
                            key: AppKeys.statusText,
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        key: AppKeys.doneScanningButton,
                        onPressed: () async {
                          setState(() {
                            _isScanning = false;
                            _status = 'Scanning stopped';
                          });
                          await locator<ScannerService>().stopScanning();
                        },
                        child: const Text('Done Scanning / OK'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Cart Total: Rs. ${_totalPrice.toStringAsFixed(2)}',
                          key: AppKeys.cartStatus,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: _buildCartList(),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: AppKeys.productSearchInput,
                          controller: _manualBarcodeController,
                          decoration: const InputDecoration(labelText: 'Manual Barcode'),
                        ),
                      ),
                      ElevatedButton(
                        key: AppKeys.addProductButton,
                        onPressed: () => _addBarcodeToCart(_manualBarcodeController.text),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  key: AppKeys.scanBarcodeButton,
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                ),
                const Divider(),
                Text(
                  'Cart Total: Rs. ${_totalPrice.toStringAsFixed(2)}',
                  key: AppKeys.cartStatus,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Credit'),
                    Switch(
                      key: AppKeys.paidCreditToggle,
                      value: _isPaid,
                      onChanged: (val) {
                        setState(() {
                          _isPaid = val;
                        });
                      },
                    ),
                    const Text('Paid'),
                    const SizedBox(width: 20),
                    Text(
                      _isPaid ? 'Paid' : 'Credit',
                      key: AppKeys.paidCreditStatus,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Expanded(
                  child: _buildCartList(),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _status,
                      key: AppKeys.statusText,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    key: AppKeys.customerPhoneInput,
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Customer Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        key: AppKeys.checkoutButton,
                        onPressed: _checkout,
                        child: const Text('Checkout'),
                      ),
                      ElevatedButton(
                        key: AppKeys.shareReceiptButton,
                        onPressed: _shareReceipt,
                        child: const Text('Share Receipt'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
