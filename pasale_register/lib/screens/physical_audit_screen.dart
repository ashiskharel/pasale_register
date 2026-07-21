import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/inventory_log.dart';
import '../services/firestore_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';

class PhysicalAuditScreen extends StatefulWidget {
  final String storeId;
  const PhysicalAuditScreen({super.key, required this.storeId});

  @override
  State<PhysicalAuditScreen> createState() => _PhysicalAuditScreenState();
}

class _PhysicalAuditScreenState extends State<PhysicalAuditScreen> {
  final _qtyCtrl = TextEditingController();
  Product? _scannedProduct;
  bool _scanning = true;
  String _status = 'Scan a barcode to audit';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startScanner();
  }

  Future<void> _startScanner() async {
    setState(() {
      _scanning = true;
      _scannedProduct = null;
      _status = 'Listening for barcode...';
    });
    
    final code = await locator<ScannerService>().scan();
    if (!mounted) return;
    
    if (code != null && code.isNotEmpty) {
      _lookupProduct(code);
    } else {
      setState(() {
        _status = 'Scan cancelled';
        _scanning = false;
      });
    }
  }

  Future<void> _lookupProduct(String code) async {
    setState(() {
      _busy = true;
      _status = 'Looking up product...';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final businessId = prefs.getString('businessId');
      
      final products = await locator<FirestoreService>()
          .streamCatalog(storeId: widget.storeId, businessId: businessId)
          .first;
      
      final product = products.cast<Product?>().firstWhere(
            (p) => p?.barcode == code || p?.id == code,
            orElse: () => null,
          );

      if (product == null) {
        setState(() {
          _status = 'Product not found. Scan again.';
          _busy = false;
        });
        _startScanner();
        return;
      }

      setState(() {
        _scannedProduct = product;
        _qtyCtrl.text = product.quantity.toStringAsFixed(0);
        _busy = false;
        _scanning = false;
        _status = 'Enter actual physical quantity';
      });
    } catch (e) {
      setState(() {
        _status = 'Error looking up product: $e';
        _busy = false;
      });
    }
  }

  Future<void> _saveAudit() async {
    if (_scannedProduct == null) return;

    final newQtyStr = _qtyCtrl.text.trim();
    final newQty = double.tryParse(newQtyStr);
    if (newQty == null || newQty < 0) {
      setState(() => _status = 'Invalid quantity');
      return;
    }

    if (newQty == _scannedProduct!.quantity) {
      setState(() => _status = 'No change in quantity.');
      await Future.delayed(const Duration(seconds: 1));
      _startScanner();
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Saving...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final product = _scannedProduct!.copyWith(quantity: newQty);

      await locator<FirestoreService>().saveProduct(
        product,
        storeId: widget.storeId,
        businessId: prefs.getString('businessId'),
        syncToBusiness: true,
      );

      final log = InventoryLog(
        id: '',
        storeId: widget.storeId,
        productId: product.id,
        productName: product.name,
        changeAmount: newQty - _scannedProduct!.quantity,
        previousQuantity: _scannedProduct!.quantity,
        newQuantity: newQty,
        reason: 'Physical Audit',
        timestamp: DateTime.now(),
      );
      await locator<FirestoreService>().saveInventoryLog(log, storeId: widget.storeId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory updated successfully')),
      );

      _startScanner();
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Failed to save: $e';
      });
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    locator<ScannerService>().stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physical Audit')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_scanning)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      locator<ScannerService>().buildScannerWidget(),
                      const Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Awaiting barcode scan...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_scannedProduct != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scannedProduct!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Barcode: ${_scannedProduct!.barcode}'),
                      const SizedBox(height: 8),
                      Text('Expected Qty: ${_scannedProduct!.quantity.toStringAsFixed(0)}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Actual Physical Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : _startScanner,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy ? null : _saveAudit,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_busy)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )),
          ],
        ),
      ),
    );
  }
}
