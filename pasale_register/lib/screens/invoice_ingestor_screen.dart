import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../models/product.dart';
import '../services/service_locator.dart';
import '../services/camera_service.dart';
import '../services/firestore_service.dart';
import '../utils/markup_calculator.dart';

class InvoiceIngestorScreen extends StatefulWidget {
  const InvoiceIngestorScreen({super.key});

  @override
  State<InvoiceIngestorScreen> createState() => _InvoiceIngestorScreenState();
}

class _InvoiceIngestorScreenState extends State<InvoiceIngestorScreen> {
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _markupController = TextEditingController();

  String _imagePath = '';
  double _calculatedSellingPrice = 0.0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _costController.addListener(_updateCalculatedPrice);
    _markupController.addListener(_updateCalculatedPrice);
  }

  void _updateCalculatedPrice() {
    final costStr = _costController.text.trim();
    final markupStr = _markupController.text.trim();
    final cost = double.tryParse(costStr) ?? 0.0;
    final markup = double.tryParse(markupStr) ?? 0.0;
    setState(() {
      final rawPrice = MarkupCalculator.calculateSellingPrice(cost, markup);
      _calculatedSellingPrice = double.parse(rawPrice.toStringAsFixed(2));
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final path = await locator<CameraService>().captureInvoicePhoto();
      setState(() {
        if (path != null) {
          _imagePath = path;
          _status = 'Photo captured successfully: $path';
        } else {
          _status = 'Photo capture cancelled';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Capture error: Exception: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _saveInvoiceProduct() async {
    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final costStr = _costController.text.trim();
    final markupStr = _markupController.text.trim();

    if (barcode.isEmpty || name.isEmpty) {
      setState(() {
        _status = 'Error: Barcode and Name are required';
      });
      return;
    }

    if (_imagePath.isEmpty) {
      setState(() {
        _status = 'Error: Invoice photo is required';
      });
      return;
    }

    final cost = double.tryParse(costStr);
    final markup = double.tryParse(markupStr);

    if (cost == null || markup == null) {
      setState(() {
        _status = 'Error: Cost and markup must be valid numbers';
      });
      return;
    }

    if (cost < 0.0 || markup < 0.0) {
      setState(() {
        _status = 'Error: Cost and markup must be non-negative';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');

    final product = Product(
      id: barcode,
      name: name,
      barcode: barcode,
      sellingPrice: _calculatedSellingPrice,
      costPrice: cost,
      markup: markup,
      storeId: storeId,
      imagePath: _imagePath.isEmpty ? null : _imagePath,
    );

    try {
      await locator<FirestoreService>().saveProduct(product, storeId: storeId);
      setState(() {
        _status = 'Invoice product saved successfully';
        _barcodeController.clear();
        _nameController.clear();
        _costController.clear();
        _markupController.clear();
        _imagePath = '';
        _calculatedSellingPrice = 0.0;
      });
    } catch (e) {
      setState(() {
        _status = 'Error saving product: $e';
      });
    }
  }

  @override
  void dispose() {
    _costController.removeListener(_updateCalculatedPrice);
    _markupController.removeListener(_updateCalculatedPrice);
    _barcodeController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _markupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Ingestor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              key: AppKeys.captureInvoiceButton,
              onPressed: _capturePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Invoice Photo'),
            ),
            if (_imagePath.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Invoice path: $_imagePath', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 20),
            TextField(
              key: AppKeys.productBarcodeInput,
              controller: _barcodeController,
              decoration: const InputDecoration(labelText: 'Barcode'),
            ),
            TextField(
              key: AppKeys.productNameInput,
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            TextField(
              key: AppKeys.costPriceInput,
              controller: _costController,
              decoration: const InputDecoration(labelText: 'Cost Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              key: AppKeys.markupInput,
              controller: _markupController,
              decoration: const InputDecoration(labelText: 'Markup %'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Calculated Selling Price: Rs. ${_calculatedSellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: AppKeys.saveInvoiceProductButton,
              onPressed: _saveInvoiceProduct,
              child: const Text('Save Ingested Product'),
            ),
            const SizedBox(height: 20),
            if (_status.isNotEmpty)
              Text(
                _status,
                key: AppKeys.statusText,
                style: const TextStyle(color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
