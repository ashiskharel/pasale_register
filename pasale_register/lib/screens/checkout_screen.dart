import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/camera_service.dart';
import '../services/cart_service.dart';
import '../services/firestore_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';
import '../services/sharing_service.dart';
import '../utils/bill_formatter.dart';
import '../utils/product_image_store.dart';

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
  bool _registeringProduct = false;
  String _storeName = 'Pasale';

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
      final product = await locator<FirestoreService>().getProduct(
        trimmed,
        storeId: storeId,
      );
      if (product != null) {
        await _pushProductToCart(product);
      } else {
        // Unrecognized barcode → register for this store (price + photo).
        final registered = await _promptRegisterProduct(
          trimmed,
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
        _cart.indexWhere((item) => item.product.barcode == product.barcode);
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

  /// Dialog: name, store price, and product photo for this store's catalog.
  Future<Product?> _promptRegisterProduct(
    String barcode, {
    String? storeId,
  }) async {
    if (!mounted) return null;
    _registeringProduct = true;

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    String? photoPath;

    try {
      final result = await showDialog<Product>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                key: AppKeys.registerUnknownProductDialog,
                title: const Text('Register for this store'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Code not in this store’s catalog:\n$barcode\n\n'
                          'Prices are store-specific — add a photo of the item/price tag if you can.',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              key: AppKeys.registerProductPhotoPreview,
                              width: 140,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: photoPath != null &&
                                      File(photoPath!).existsSync()
                                  ? Image.file(
                                      File(photoPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : photoPath != null
                                      ? const Icon(Icons.image, size: 48)
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: AppKeys.registerProductPhotoButton,
                          onPressed: () async {
                            try {
                              // Pause continuous scan so still capture can use camera.
                              await locator<ScannerService>().stopScanning();
                              final path = await locator<CameraService>()
                                  .captureProductPhoto();
                              if (path != null && path.isNotEmpty) {
                                setDialogState(() => photoPath = path);
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Photo failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            photoPath == null
                                ? 'Take product photo'
                                : 'Retake photo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: AppKeys.registerProductNameInput,
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product name *',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: AppKeys.registerProductPriceInput,
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'This store’s selling price (Rs.) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null) return 'Enter a valid price';
                            if (n < 0) return 'Price cannot be negative';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: AppKeys.registerProductCostInput,
                          controller: costController,
                          decoration: const InputDecoration(
                            labelText: 'Cost price (Rs.) optional',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v.trim());
                            if (n == null) return 'Enter a valid number';
                            if (n < 0) return 'Cost cannot be negative';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    key: AppKeys.registerProductSkipButton,
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    key: AppKeys.registerProductSaveButton,
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final name = nameController.text.trim();
                      final selling =
                          double.parse(priceController.text.trim());
                      final costText = costController.text.trim();
                      final cost =
                          costText.isEmpty ? 0.0 : double.parse(costText);
                      if (selling < cost) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Selling price cannot be less than cost price',
                            ),
                          ),
                        );
                        return;
                      }
                      final markup =
                          cost > 0 ? ((selling - cost) / cost) * 100.0 : 0.0;

                      String? storedImage = photoPath;
                      if (photoPath != null &&
                          storeId != null &&
                          storeId.isNotEmpty) {
                        storedImage = await persistProductImage(
                          sourcePath: photoPath!,
                          storeId: storeId,
                          barcode: barcode,
                        );
                      }

                      final product = Product(
                        id: barcode,
                        name: name,
                        barcode: barcode,
                        sellingPrice: selling,
                        costPrice: cost,
                        markup: markup,
                        storeId: storeId,
                        imagePath: storedImage,
                      );
                      try {
                        await locator<FirestoreService>().saveProduct(
                          product,
                          storeId: storeId,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(product);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Save & add'),
                  ),
                ],
              );
            },
          );
        },
      );
      return result;
    } finally {
      _registeringProduct = false;
      // Do not auto-call scan() here — the scan loop resumes on its own
      // once _registeringProduct is false; ensureSession restarts the stream.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        priceController.dispose();
        costController.dispose();
      });
    }
  }

  Future<void> _scanBarcode() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _status = 'Scanning… point at barcode or QR';
    });
    try {
      while (_isScanning) {
        // Don't pull next scan while the register dialog is open.
        if (_registeringProduct) {
          await Future.delayed(const Duration(milliseconds: 150));
          continue;
        }
        // Restart camera stream after product photo capture stopped it.
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
    if (_cart.isEmpty) {
      return const Center(
        child: Text(
          'Cart is empty.\nScan or enter a barcode to add items.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        final img = item.product.imagePath;
        Widget? leading;
        if (img != null && img.isNotEmpty) {
          if (img.startsWith('/') || img.contains(':\\') || img.contains(':/')) {
            final f = File(img);
            leading = f.existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(f, width: 48, height: 48, fit: BoxFit.cover),
                  )
                : const Icon(Icons.inventory_2_outlined);
          } else {
            leading = const Icon(Icons.inventory_2_outlined);
          }
        }
        return ListTile(
          key: ValueKey('cart_item_${item.product.barcode}'),
          leading: leading ?? const Icon(Icons.inventory_2_outlined),
          title: Text(item.product.name),
          subtitle: Text(
            'Rs. ${item.product.sellingPrice.toStringAsFixed(2)} × ${item.quantity}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('decrement_qty_${item.product.barcode}'),
                icon: const Icon(Icons.remove),
                onPressed: () {
                  locator<CartService>()
                      .decrementQuantity(item.product.barcode);
                },
              ),
              Text('${item.quantity}'),
              IconButton(
                key: ValueKey('increment_qty_${item.product.barcode}'),
                icon: const Icon(Icons.add),
                onPressed: () {
                  final success = locator<CartService>()
                      .incrementQuantity(item.product.barcode);
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

  Widget _cartHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        'Cart Total: Rs. ${_totalPrice.toStringAsFixed(2)}',
        key: AppKeys.cartStatus,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              child: const Text('Done Scanning / OK'),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: AppKeys.productSearchInput,
                  controller: _manualBarcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Manual Barcode / QR',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _addBarcodeToCart,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: AppKeys.addProductButton,
                onPressed: () =>
                    _addBarcodeToCart(_manualBarcodeController.text),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: AppKeys.scanBarcodeButton,
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode / QR'),
            ),
          ),
        ),
        const Divider(),
        _cartHeader(),
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
        Expanded(child: _buildCartList()),
        _statusLine(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            key: AppKeys.customerPhoneInput,
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Customer Phone Number',
              border: OutlineInputBorder(),
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Cart')),
      body: _isScanning
          ? _buildScanningLayout(context)
          : _buildIdleLayout(),
    );
  }
}
