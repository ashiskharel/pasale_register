import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../models/vendor_invoice.dart';
import '../models/inventory_log.dart';
import '../services/camera_service.dart';
import '../services/firestore_service.dart';
import '../services/invoice_ocr_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';
import '../theme/pasale_theme.dart';
import '../utils/invoice_line_parser.dart';
import '../utils/string_similarity.dart';

/// Scan vendor invoice with live camera + OCR → review line items → catalog.
class InvoiceIngestorScreen extends StatefulWidget {
  const InvoiceIngestorScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InvoiceIngestorScreen> createState() => _InvoiceIngestorScreenState();
}

class _InvoiceIngestorScreenState extends State<InvoiceIngestorScreen> {
  final _ocr = InvoiceOcrService();
  final _defaultMarkup = TextEditingController(text: '20');
  final _vendorNameCtrl = TextEditingController();

  bool _cameraReady = false;
  bool _busy = false;
  String? _imagePath;
  String _status = '';
  String _rawOcr = '';
  List<InvoiceLineDraft> _lines = [];
  
  List<Vendor> _existingVendors = [];
  String? _selectedVendorId;

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _prepareCamera();
  }

  Future<void> _loadVendors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('storeId');
      if (storeId != null && storeId.isNotEmpty) {
        final vendors = await locator<FirestoreService>().fetchVendors(storeId: storeId);
        if (mounted) setState(() => _existingVendors = vendors);
      }
    } catch (_) {}
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _busy = true;
      _status = 'Starting camera…';
    });
    try {
      try {
        await locator<ScannerService>().stopScanning();
      } catch (_) {}
      await locator<CameraService>().prepareProductPhotoSession();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() {
        _cameraReady = locator<CameraService>().buildProductPhotoPreview() != null;
        _busy = false;
        _status = _cameraReady
            ? 'Frame the invoice, then scan with OCR'
            : 'Camera preview unavailable — try Retry';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _cameraReady = false;
        _status = 'Camera error: $e';
      });
    }
  }

  Future<void> _captureAndOcr() async {
    setState(() {
      _busy = true;
      _status = 'Capturing & reading invoice…';
    });
    try {
      await locator<CameraService>().prepareProductPhotoSession();
      final path = await locator<CameraService>().captureProductPhoto();
      if (path == null || path.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'Capture cancelled';
        });
        return;
      }
      final markup = double.tryParse(_defaultMarkup.text.trim()) ?? 20;
      final parser = InvoiceLineParser(defaultMarkupPercent: markup);
      _ocr.parser = parser;
      final result = await _ocr.parseInvoiceImage(path);
      if (!mounted) return;

      var lines = result.lines;
      // Soft fallback: if OCR read text but heuristics found 0 items,
      // seed editable rows from raw lines so the cashier can fix prices.
      if (lines.isEmpty && result.rawLineCount > 0) {
        lines = _softRowsFromRaw(result.rawText, markup);
      }

      setState(() {
        _imagePath = path;
        _lines = lines;
        _rawOcr = result.rawText;
        if (_vendorNameCtrl.text.isEmpty && result.vendorName.isNotEmpty) {
           final bestMatch = findBestVendorMatch(result.vendorName, _existingVendors);
           if (bestMatch != null) {
             _selectedVendorId = bestMatch.id;
             _vendorNameCtrl.text = bestMatch.name;
           } else {
             _selectedVendorId = null;
             _vendorNameCtrl.text = result.vendorName;
           }
        }
        _busy = false;
        if (result.rawLineCount == 0) {
          _status =
              'On-device OCR saw no text. Better light, fill the frame, hold steady, then rescan.';
        } else if (result.lines.isEmpty && lines.isNotEmpty) {
          _status =
              'OCR read ${result.rawLineCount} line(s) but could not auto-split prices. '
              'Edit the draft rows below (or + Add row).';
        } else if (lines.isEmpty) {
          _status =
              'No line items detected. OCR is on-device (ML Kit). Try a clearer photo.';
        } else {
          _status =
              'Found ${lines.length} line(s) from on-device OCR. Review, edit, then save.';
        }
        _cameraReady =
            locator<CameraService>().buildProductPhotoPreview() != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'OCR error: $e';
      });
    }
  }

  Future<void> _saveSelected() async {
    final selected = _lines.where((l) => l.selected).toList();
    if (selected.isEmpty) {
      setState(() => _status = 'Select at least one line to save');
      return;
    }
    for (final line in selected) {
      if (line.name.trim().isEmpty) {
        setState(() => _status = 'Every selected line needs a product name');
        return;
      }
      if (line.costPrice < 0 || line.sellingPrice < 0) {
        setState(() => _status = 'Prices cannot be negative');
        return;
      }
      if (line.sellingPrice < line.costPrice) {
        setState(() => _status = 'Sell price cannot be less than cost for “${line.name}”');
        return;
      }
    }

    setState(() {
      _busy = true;
      _status = 'Saving ${selected.length} product(s)…';
    });

    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    if (storeId == null) return;

    var ok = 0;
    try {
      String? vendorIdForProducts = _selectedVendorId;
      final typedVendorName = _vendorNameCtrl.text.trim();
      
      if (vendorIdForProducts == null && typedVendorName.isNotEmpty) {
        Vendor? exactMatch;
        try {
          exactMatch = _existingVendors.firstWhere(
            (v) => v.name.toLowerCase() == typedVendorName.toLowerCase()
          );
        } catch (_) {}
        
        if (exactMatch != null) {
          vendorIdForProducts = exactMatch.id;
        } else {
          final newId = 'VEND_${DateTime.now().millisecondsSinceEpoch}';
          final vendor = Vendor(id: newId, name: typedVendorName, storeId: storeId);
          await locator<FirestoreService>().saveVendor(vendor, storeId: storeId);
          vendorIdForProducts = newId;
        }
      }

      double totalInvoiceAmount = 0.0;
      List<String> invoiceLineItems = [];

      for (final line in selected) {
        totalInvoiceAmount += (line.costPrice * line.quantity);
        invoiceLineItems.add('${line.name} x${line.quantity} @ Rs.${line.costPrice}');

        final code = line.barcode.trim().isNotEmpty
            ? line.barcode.trim()
            : 'INV_${DateTime.now().millisecondsSinceEpoch}_$ok';
        final markupPct = line.costPrice >= 0.01
            ? ((line.sellingPrice - line.costPrice) / line.costPrice) * 100
            : line.markupPercent;
            
        // Fetch existing to get current quantity
        final existingProduct = await locator<FirestoreService>().getProduct(
          code, 
          storeId: storeId,
          businessId: prefs.getString('businessId'),
        );
        
        final previousQty = existingProduct?.quantity ?? 0.0;
        final newQty = previousQty + line.quantity;

        final product = Product(
          id: existingProduct?.id ?? code,
          name: line.name.trim(),
          barcode: code,
          sellingPrice: line.sellingPrice,
          costPrice: line.costPrice,
          markup: markupPct,
          quantity: newQty,
          storeId: storeId,
          imagePath: _imagePath,
          notes: line.rawLine.isNotEmpty ? 'Invoice OCR: ${line.rawLine}' : null,
          vendorIds: vendorIdForProducts != null 
              ? [...(existingProduct?.vendorIds ?? []).where((id) => id != vendorIdForProducts), vendorIdForProducts] 
              : existingProduct?.vendorIds,
        );
        
        await locator<FirestoreService>().saveProduct(
          product,
          storeId: storeId,
          businessId: prefs.getString('businessId'),
          syncToBusiness: true,
        );
        
        // Log inventory
        final log = InventoryLog(
          id: '',
          storeId: storeId,
          productId: product.id,
          productName: product.name,
          changeAmount: line.quantity,
          previousQuantity: previousQty,
          newQuantity: newQty,
          reason: 'Vendor Invoice ${typedVendorName.isNotEmpty ? "($typedVendorName)" : ""}'.trim(),
          timestamp: DateTime.now(),
        );
        await locator<FirestoreService>().saveInventoryLog(log, storeId: storeId);

        ok++;
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      if (vendorIdForProducts != null) {
        final vInvoiceId = 'VI_${DateTime.now().millisecondsSinceEpoch}';
        final vInvoice = VendorInvoice(
          id: vInvoiceId,
          storeId: storeId,
          vendorUid: vendorIdForProducts,
          vendorName: typedVendorName.isNotEmpty ? typedVendorName : vendorIdForProducts,
          totalAmount: totalInvoiceAmount,
          issuedAt: DateTime.now(),
          dueDate: DateTime.now(),
          status: 'pending',
          lineItems: invoiceLineItems,
        );
        await locator<FirestoreService>().saveVendorInvoice(vInvoice, storeId: storeId);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Saved $ok product(s) to store catalog';
        _lines = [];
        _imagePath = null;
        _vendorNameCtrl.clear();
        _selectedVendorId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Save error after $ok item(s): $e';
      });
    }
  }

  void _addBlankLine() {
    setState(() {
      _lines.add(
        InvoiceLineDraft(
          name: '',
          costPrice: 0,
          sellingPrice: 0,
          quantity: 1.0,
          markupPercent:
              double.tryParse(_defaultMarkup.text.trim()) ?? 20,
        ),
      );
    });
  }

  /// When structured parse fails, offer raw OCR lines as editable drafts.
  List<InvoiceLineDraft> _softRowsFromRaw(String raw, double markup) {
    final drafts = <InvoiceLineDraft>[];
    for (final line in raw.split(RegExp(r'[\n\r]+'))) {
      final t = line.trim();
      if (t.length < 3) continue;
      if (RegExp(r'^(total|thank|invoice|date|tel)', caseSensitive: false)
          .hasMatch(t)) {
        continue;
      }
      // Prefer lines that still have some letters (product-ish)
      if (!RegExp(r'[A-Za-z\u0900-\u097F]').hasMatch(t)) continue;
      drafts.add(
        InvoiceLineDraft(
          name: t,
          costPrice: 0,
          sellingPrice: 0,
          quantity: 1.0,
          markupPercent: markup,
          rawLine: t,
          selected: drafts.length < 15,
        ),
      );
      if (drafts.length >= 20) break;
    }
    return drafts;
  }

  @override
  void dispose() {
    _defaultMarkup.dispose();
    _vendorNameCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Scan Vendor Invoice',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Live camera → OCR line items → edit cost/sell → save to this store’s catalog.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _defaultMarkup,
                decoration: const InputDecoration(
                  labelText: 'Default markup %',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _busy ? null : _prepareCamera,
              child: const Text('Retry cam'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Live preview / captured still
        ClipRRect(
          borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: PasaleTheme.hairline),
              borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
            ),
            child: _buildCameraPane(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: AppKeys.captureInvoiceButton,
          onPressed: _busy ? null : _captureAndOcr,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_busy ? 'Working…' : 'Capture & OCR invoice'),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_status, key: AppKeys.statusText, style: theme.textTheme.bodySmall),
        ],
        if (_rawOcr.isNotEmpty && _lines.isEmpty) ...[
          const SizedBox(height: 12),
          Text('OCR text (on-device)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: PasaleTheme.hairline),
              borderRadius: BorderRadius.circular(PasaleTheme.radiusMd),
            ),
            child: Text(
              _rawOcr.length > 800 ? '${_rawOcr.substring(0, 800)}…' : _rawOcr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
        ],
        if (_lines.isNotEmpty) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<String?>(
                width: constraints.maxWidth,
                controller: _vendorNameCtrl,
                initialSelection: _selectedVendorId,
                label: const Text('Vendor (Optional)'),
                leadingIcon: const Icon(Icons.business),
                enableFilter: true,
                requestFocusOnTap: true,
                onSelected: (val) {
                  setState(() {
                    _selectedVendorId = val;
                  });
                },
                dropdownMenuEntries: [
                  ..._existingVendors.map((v) => DropdownMenuEntry(
                    value: v.id,
                    label: v.name,
                  )),
                ],
              );
            }
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Line items (${_lines.where((l) => l.selected).length}/${_lines.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _addBlankLine,
                child: const Text('+ Add row'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_lines.length, _buildLineCard),
          const SizedBox(height: 12),
          FilledButton(
            key: AppKeys.saveInvoiceProductButton,
            onPressed: _busy ? null : _saveSelected,
            child: const Text('Save selected to catalog'),
          ),
        ],
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Vendor Invoice')),
      body: body,
    );
  }

  Widget _buildCameraPane() {
    if (_imagePath != null &&
        _imagePath!.isNotEmpty &&
        File(_imagePath!).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_imagePath!), fit: BoxFit.contain),
          Positioned(
            right: 8,
            top: 8,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _imagePath = null;
                  _lines = [];
                });
                _prepareCamera();
              },
              child: const Text('Rescan', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      );
    }
    if (_busy && !_cameraReady) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    final preview = locator<CameraService>().buildProductPhotoPreview();
    if (preview != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          preview,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Text(
              'Align full invoice in frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white54),
          const SizedBox(height: 8),
          const Text(
            'No live preview',
            style: TextStyle(color: Colors.white70),
          ),
          TextButton(
            onPressed: _prepareCamera,
            child: const Text('Retry camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    final nameCtrl = TextEditingController(text: line.name);
    final costCtrl =
        TextEditingController(text: line.costPrice.toStringAsFixed(2));
    final sellCtrl =
        TextEditingController(text: line.sellingPrice.toStringAsFixed(2));
    final qtyCtrl = TextEditingController(text: line.quantity.toString());
    final codeCtrl = TextEditingController(text: line.barcode);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: (v) {
                    setState(() => line.selected = v ?? false);
                  },
                ),
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _lines.removeAt(index)),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Product name',
                isDense: true,
              ),
              onChanged: (v) => line.name = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Barcode (optional)',
                      isDense: true,
                    ),
                    onChanged: (v) => line.barcode = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      line.quantity = double.tryParse(v) ?? line.quantity;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: costCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cost (Rs.)',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      line.costPrice = double.tryParse(v) ?? line.costPrice;
                      line.recomputeSellFromMarkup();
                      sellCtrl.text = line.sellingPrice.toStringAsFixed(2);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: sellCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sell (Rs.)',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      line.sellingPrice =
                          double.tryParse(v) ?? line.sellingPrice;
                      line.recomputeMarkupFromPrices();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
