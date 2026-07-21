import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mlkit_camera/mlkit_camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/inventory_log.dart';
import '../models/store_customer.dart';
import '../models/store_invoice.dart';
import '../services/cart_service.dart';
import '../services/firestore_service.dart';
import '../services/invoice_history_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';
import '../services/sharing_service.dart';
import '../utils/bill_formatter.dart';
import '../utils/price_ocr_parser.dart';
import '../widgets/register_product_dialog.dart';

/// Live scan target: barcodes vs printed price tags (OCR).
enum _ScanMode { barcode, priceTag }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.embedded = false});

  /// When true, omit Scaffold/AppBar (parent shell provides chrome).
  final bool embedded;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _manualBarcodeController = TextEditingController();
  final _phoneController = TextEditingController();
  String _status = '';
  bool _isScanning = false;
  bool _registeringProduct = false;
  String _storeName = 'Pasale';
  _ScanMode _scanMode = _ScanMode.barcode;

  List<CartItem> get _cart => locator<CartService>().items;

  double get _totalPrice => locator<CartService>().totalPrice;

  bool get _checkedOut => locator<CartService>().checkoutCompleted;
  set _checkedOut(bool value) =>
      locator<CartService>().checkoutCompleted = value;

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
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('storeId');
      final businessId = prefs.getString('businessId');
      final product = await locator<FirestoreService>().getProduct(
        trimmed,
        storeId: storeId,
        businessId: businessId,
      );
      if (product != null) {
        await _pushProductToCart(product);
      } else {
        // Unrecognized barcode → register for this store (price + photo).
        final registered = await _promptRegisterProduct(
          barcode: trimmed,
          storeId: storeId,
        );
        if (registered != null) {
          await _pushProductToCart(registered);
        } else {
          setState(() {
            _status = 'Skipped unknown product: $trimmed';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Error loading product: $e';
      });
    }
  }

  Future<void> _pushProductToCart(Product product) async {
    final existingIndex =
        _cart.indexWhere((item) => item.product.id == product.id);
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
  }

  /// Register product for this store (unknown barcode, OCR price tag, open item).
  Future<Product?> _promptRegisterProduct({
    String? barcode,
    String? storeId,
    double? initialPrice,
    String? initialNotes,
    String? headline,
    RegisterProductKind kind = RegisterProductKind.unknownBarcode,
  }) async {
    if (!mounted) return null;
    _registeringProduct = true;
    // Pause continuous scan while the form (and product camera) is open.
    if (_isScanning) {
      try {
        await locator<ScannerService>().stopScanning();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final businessId = prefs.getString('businessId');
    try {
      return await showRegisterProductDialog(
        context: context,
        kind: kind,
        barcode: barcode,
        storeId: storeId,
        businessId: businessId,
        initialPrice: initialPrice,
        initialNotes: initialNotes,
        headline: headline,
      );
    } finally {
      _registeringProduct = false;
    }
  }

  Future<void> _addOpenItem() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    final registered = await _promptRegisterProduct(
      storeId: storeId,
      kind: RegisterProductKind.openItem,
    );
    if (registered != null) {
      await _pushProductToCart(registered);
    } else {
      setState(() => _status = 'Skipped open item');
    }
  }

  Future<void> _handleOcrLabel(OcrLabelParse parse) async {
    if (!parse.hasPrice) return;
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    final registered = await _promptRegisterProduct(
      storeId: storeId,
      initialPrice: parse.price,
      initialNotes: parse.notes ?? parse.rawSnippet,
      kind: RegisterProductKind.priceTag,
    );
    if (registered != null) {
      await _pushProductToCart(registered);
    } else {
      setState(() => _status = 'Skipped price-tag product');
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _status = _scanMode == _ScanMode.priceTag
          ? 'Price tag mode — point at printed price'
          : 'Scanning… point at barcode or QR';
    });
    try {
      while (_isScanning) {
        if (_registeringProduct) {
          await Future.delayed(const Duration(milliseconds: 150));
          continue;
        }

        if (_scanMode == _ScanMode.priceTag) {
          if (mounted) {
            setState(() {
              _status =
                  'Reading price… need clear “Rs. …” (not random numbers). '
                  'Hold steady for a moment.';
            });
          }
          final parse = await locator<ScannerService>().scanPriceLabel();
          if (!_isScanning) break;
          if (parse != null && parse.hasPrice) {
            if (mounted) {
              setState(() {
                _status =
                    'Found Rs. ${parse.price!.toStringAsFixed(2)} — confirm details';
              });
            }
            await _handleOcrLabel(parse);
          } else {
            setState(() => _status = 'No price read — try again');
          }
        } else {
          final barcode = await locator<ScannerService>().scan();
          if (!_isScanning) break;
          if (barcode != null) {
            final trimmed = barcode.trim();
            if (trimmed.isEmpty) {
              setState(() => _status = 'Scan cancelled');
            } else {
              await _addBarcodeToCart(trimmed);
            }
          } else {
            setState(() => _status = 'Scan cancelled');
          }
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      setState(() {
        _status = 'Scan error: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScanning() async {
    setState(() {
      _isScanning = false;
      _status = 'Scanning stopped';
    });
    await locator<ScannerService>().stopScanning();
  }

  Future<void> _setScanMode(_ScanMode mode) async {
    if (_scanMode == mode) return;
    setState(() {
      _scanMode = mode;
      _status = mode == _ScanMode.priceTag
          ? 'Price tag mode selected'
          : 'Barcode mode selected';
    });
    if (_isScanning) {
      try {
        await locator<ScannerService>().setVisionMode(
          mode == _ScanMode.priceTag
              ? CameraVisionMode.text
              : CameraVisionMode.barcodeQr,
        );
      } catch (e) {
        setState(() => _status = 'Mode switch: $e');
      }
    }
  }

  /// Checkout: choose cash vs credit once, record invoice, clear cart.
  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      setState(() => _status = 'Cart is empty');
      return;
    }

    final payment = await showModalBottomSheet<InvoicePayment>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Complete checkout',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${_totalPrice.toStringAsFixed(2)} · how was this paid?',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: AppKeys.markPaidButton,
                  onPressed: () => Navigator.pop(ctx, InvoicePayment.cash),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Cash (paid)'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: AppKeys.markCreditButton,
                  onPressed: () => Navigator.pop(ctx, InvoicePayment.credit),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Credit'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (payment == null || !mounted) return;

    String? customerName;
    String? customerEmail;
    var phone = _phoneController.text.trim();

    if (payment == InvoicePayment.credit) {
      final details = await _promptCreditCustomer(prefillPhone: phone);
      if (details == null || !mounted) return;
      customerName = details.$1;
      phone = details.$2;
      customerEmail = details.$3;
      _phoneController.text = phone;
    } else if (phone.isNotEmpty &&
        !BillFormatter.isValidNepaliPhoneNumber(phone)) {
      setState(() => _status = 'Error: Invalid phone number format');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');

    final cartSnap = List.of(_cart);
    final total = _totalPrice;
    final invoice = StoreInvoice.fromCart(
      cart: cartSnap,
      total: total,
      payment: payment,
      customerPhone: phone.isEmpty ? null : phone,
      customerName: customerName,
      customerEmail: customerEmail,
      storeId: storeId,
      storeName: _storeName,
    );

    try {
      if (locator.isRegistered<InvoiceHistoryService>()) {
        await locator<InvoiceHistoryService>().add(invoice);
        
        // Deduct inventory stock for each sold item
        if (storeId != null) {
          final firestore = locator<FirestoreService>();
          final businessId = prefs.getString('businessId');
          
          for (final entry in cartSnap) {
            final product = entry.product;
            final qtySold = entry.quantity;
            if (qtySold > 0) {
              final existingProduct = await firestore.getProduct(product.id, storeId: storeId, businessId: businessId);
              if (existingProduct != null) {
                // Atomic stock deduction
                await FirebaseFirestore.instance
                    .collection('stores')
                    .doc(storeId)
                    .collection('products')
                    .doc(product.id)
                    .update({'quantity': FieldValue.increment(-qtySold)});
                if (businessId != null && businessId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(businessId)
                      .collection('catalog')
                      .doc(product.id)
                      .update({'quantity': FieldValue.increment(-qtySold)});
                }
                final newQty = existingProduct.quantity - qtySold;
                
                final log = InventoryLog(
                  id: '',
                  storeId: storeId,
                  productId: existingProduct.id,
                  productName: existingProduct.name,
                  changeAmount: -qtySold.toDouble(),
                  previousQuantity: existingProduct.quantity,
                  newQuantity: newQty,
                  reason: 'Sale', // Could add invoice.id if it was available here
                  timestamp: DateTime.now(),
                );
                await firestore.saveInventoryLog(log, storeId: storeId);
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error recording sale: $e';
        });
      }
    }

    if (phone.isNotEmpty) {
      final receiptText = payment == InvoicePayment.cash
          ? BillFormatter.generateReceipt(
              cart: cartSnap,
              totalPrice: total,
              isPaid: true,
              checkedOut: true,
              storeName: _storeName,
            )
          : BillFormatter.generateDetailedCreditInvoice(
              cart: cartSnap,
              totalPrice: total,
              storeName: _storeName,
              customerPhone: phone,
            );
      try {
        await locator<SharingService>().shareReceipt(receiptText, phone);
      } catch (_) {}
    }

    locator<CartService>().clear();
    _phoneController.clear();
    setState(() {
      _checkedOut = false;
      _status = payment == InvoicePayment.cash
          ? 'Checkout saved · cash Rs. ${total.toStringAsFixed(2)}'
          : 'Checkout saved · credit for $customerName · Rs. ${total.toStringAsFixed(2)}';
    });
  }

  /// Returns (name, phone, email?) for credit sales.
  Future<(String, String, String?)?> _promptCreditCustomer({
    String prefillPhone = '',
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: prefillPhone);
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final recentCustomers = locator<InvoiceHistoryService>().recentCustomers(limit: 50);

    try {
      return await showDialog<(String, String, String?)>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Credit customer'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Name and phone are required for credit record-keeping.',
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<StoreCustomer>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<StoreCustomer>.empty();
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return recentCustomers.where((c) =>
                            c.phone.toLowerCase().contains(query) ||
                            c.name.toLowerCase().contains(query));
                      },
                      displayStringForOption: (c) => c.phone,
                      onSelected: (StoreCustomer c) {
                        phoneCtrl.text = c.phone;
                        nameCtrl.text = c.name;
                        if (c.email != null) emailCtrl.text = c.email!;
                      },
                      fieldViewBuilder:
                          (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (phoneCtrl.text.isEmpty && textEditingController.text.isNotEmpty) {
                          phoneCtrl.text = textEditingController.text;
                        }
                        textEditingController.addListener(() {
                          phoneCtrl.text = textEditingController.text;
                        });
                        return TextFormField(
                          key: AppKeys.creditCustomerPhoneInput,
                          controller: textEditingController,
                          focusNode: focusNode,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone *',
                            hintText: '98XXXXXXXX',
                          ),
                          validator: (v) {
                            final p = v?.trim() ?? '';
                            if (p.isEmpty) return 'Phone required';
                            if (!BillFormatter.isValidNepaliPhoneNumber(p)) {
                              return 'Invalid mobile (98/97.)';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: AppKeys.creditCustomerNameInput,
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Customer name *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: AppKeys.creditCustomerEmailInput,
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: AppKeys.creditCustomerConfirmButton,
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final email = emailCtrl.text.trim();
                  Navigator.pop(
                    ctx,
                    (
                      nameCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                      email.isEmpty ? null : email,
                    ),
                  );
                },
                child: const Text('Save credit sale'),
              ),
            ],
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        phoneCtrl.dispose();
        emailCtrl.dispose();
      });
    }
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
      isPaid: true,
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
    if (_cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Cart is empty\nScan or enter a barcode to add items',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _cart[index];
        final img = item.product.imagePath;
        Widget leading = CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(Icons.inventory_2_outlined, color: scheme.primary, size: 20),
        );
        if (img != null && img.isNotEmpty) {
          if (img.startsWith('/') || img.contains(r':\') || img.contains(':/')) {
            final f = File(img);
            if (f.existsSync()) {
              leading = ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(f, width: 44, height: 44, fit: BoxFit.cover),
              );
            }
          }
        }
        return Card(
          child: ListTile(
            key: ValueKey('cart_item_${item.product.id}'),
            leading: leading,
            title: Text(item.product.name),
            subtitle: Text(
              'Rs. ${item.product.sellingPrice.toStringAsFixed(2)} × ${item.quantity}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  key: ValueKey('decrement_qty_${item.product.id}'),
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () {
                    locator<CartService>()
                        .decrementQuantity(item.product.id);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filledTonal(
                  key: ValueKey('increment_qty_${item.product.id}'),
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () {
                    final success = locator<CartService>()
                        .incrementQuantity(item.product.id);
                    if (!success) {
                      setState(() {
                        _status = 'Error: Max quantity reached';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cartHeader() {
    return Text(
      'Cart Total: Rs. ${_totalPrice.toStringAsFixed(2)}',
      key: AppKeys.cartStatus,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _statusLine() {
    if (_status.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        _status,
        key: AppKeys.statusText,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cameraPane() {
    return Container(
      key: const Key('scanPreview'),
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      clipBehavior: Clip.hardEdge,
      child: locator<ScannerService>().buildScannerWidget(),
    );
  }

  /// Portrait phones: camera on top, cart below (easier one-handed POS).
  /// Wide / landscape: side-by-side.
  Widget _buildScanningLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 600 || size.width > size.height;

    final cameraBlock = Column(
      children: [
        Expanded(flex: wide ? 1 : 3, child: _cameraPane()),
        _statusLine(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: AppKeys.doneScanningButton,
              onPressed: _stopScanning,
              child: Text(
                _scanMode == _ScanMode.priceTag
                    ? 'Done · price tag'
                    : 'Done Scanning / OK',
              ),
            ),
          ),
        ),
      ],
    );

    final cartBlock = Column(
      children: [
        _cartHeader(),
        const Divider(height: 1),
        Expanded(child: _buildCartList()),
      ],
    );

    if (wide) {
      // Horizontal split — tablet / landscape.
      return Row(
        children: [
          Expanded(flex: 5, child: cameraBlock),
          const VerticalDivider(width: 1),
          Expanded(flex: 4, child: cartBlock),
        ],
      );
    }

    // Vertical split — typical phone portrait.
    return Column(
      children: [
        Expanded(flex: 5, child: cameraBlock),
        const Divider(height: 1),
        Expanded(flex: 4, child: cartBlock),
      ],
    );
  }

  Widget _buildIdleLayout() {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<_ScanMode>(
            segments: const [
              ButtonSegment(
                value: _ScanMode.barcode,
                label: Text('Barcode'),
                icon: Icon(Icons.qr_code_2_rounded, size: 18),
              ),
              ButtonSegment(
                value: _ScanMode.priceTag,
                label: Text('Price tag'),
                icon: Icon(Icons.text_fields_rounded, size: 18),
              ),
            ],
            selected: {_scanMode},
            onSelectionChanged: (s) => _setScanMode(s.first),
          ),
        ),
        // Hidden keys for tests / accessibility on mode segments
        Offstage(
          offstage: true,
          child: Row(
            children: [
              SizedBox(key: AppKeys.scanModeBarcode),
              SizedBox(key: AppKeys.scanModePriceTag),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: AppKeys.productSearchInput,
                  controller: _manualBarcodeController,
                  decoration: InputDecoration(
                    labelText: _scanMode == _ScanMode.barcode
                        ? 'Barcode / QR'
                        : 'Optional code',
                    hintText: _scanMode == _ScanMode.barcode
                        ? 'Scan or type code'
                        : 'Leave empty for OCR id',
                    isDense: true,
                    prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  ),
                  onSubmitted: _addBarcodeToCart,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                key: AppKeys.addProductButton,
                onPressed: () =>
                    _addBarcodeToCart(_manualBarcodeController.text),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: AppKeys.scanBarcodeButton,
                  onPressed: _startScanning,
                  icon: Icon(
                    _scanMode == _ScanMode.priceTag
                        ? Icons.document_scanner_rounded
                        : Icons.qr_code_scanner_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _scanMode == _ScanMode.priceTag
                        ? 'Scan price tag'
                        : 'Open scanner',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Loose / open / weighed items without barcode or price tag.
              FilledButton.tonalIcon(
                key: AppKeys.addOpenItemButton,
                onPressed: _addOpenItem,
                icon: const Icon(Icons.scale_outlined, size: 18),
                label: const Text('Loose', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _cartHeader(),
        ),
        Expanded(child: _buildCartList()),
        _statusLine(),
        Material(
          color: scheme.surfaceContainerLowest,
          elevation: 8,
          shadowColor: Colors.black26,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Subtotal  Rs. ${_totalPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: AppKeys.customerPhoneInput,
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Customer phone',
                      hintText: '98XXXXXXXX',
                      isDense: true,
                      prefixIcon: Icon(Icons.phone_android_rounded, size: 18),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: AppKeys.checkoutButton,
                          onPressed: _cart.isEmpty ? null : _checkout,
                          child: const Text('Checkout'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: AppKeys.shareReceiptButton,
                          onPressed: _cart.isEmpty ? null : _shareReceipt,
                          child: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _isScanning
        ? _buildScanningLayout(context)
        : _buildIdleLayout();
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Cart')),
      body: body,
    );
  }
}
