import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/firestore_service.dart';
import '../services/scanner_service.dart';
import '../services/service_locator.dart';
import '../utils/product_image_store.dart';
import 'product_photo_capture.dart';

/// Why the register form was opened.
enum RegisterProductKind {
  /// Scanned barcode not in catalog.
  unknownBarcode,

  /// Price-tag OCR, no code on package.
  priceTag,

  /// Catalog → Add product.
  catalog,

  /// Catalog → edit existing product.
  edit,

  /// Loose / open / weighed / unpriced line on checkout.
  openItem,
}

/// Shared product registration form used by checkout (unknown scan / OCR /
/// open item) and catalog (Add / Edit product). Includes photo + optional barcode scan.
Future<Product?> showRegisterProductDialog({
  required BuildContext context,
  RegisterProductKind kind = RegisterProductKind.unknownBarcode,
  String? barcode,
  String? storeId,
  String? businessId,
  double? initialPrice,
  double? initialCost,
  String? initialNotes,
  String? initialName,
  String? initialImagePath,
  /// When set, form is prefilled and [kind] should be [RegisterProductKind.edit].
  Product? existingProduct,
  String? headline,
  String? title,
  String? confirmLabel,
}) async {
  final effectiveKind =
      existingProduct != null ? RegisterProductKind.edit : kind;

  final codeSeed = (existingProduct?.barcode ?? barcode)?.trim();
  final codeSeedNonEmpty =
      (codeSeed != null && codeSeed.isNotEmpty) ? codeSeed : null;

  final nameController = TextEditingController(
    text: existingProduct?.name ?? initialName ?? '',
  );
  final barcodeController = TextEditingController(text: codeSeedNonEmpty ?? '');
  final sell = existingProduct?.sellingPrice ?? initialPrice;
  final priceController = TextEditingController(
    text: sell != null
        ? sell.toStringAsFixed(sell == sell.roundToDouble() ? 0 : 2)
        : '',
  );
  final costVal = existingProduct?.costPrice ?? initialCost ?? 0.0;
  final costController = TextEditingController(
    text: costVal == 0
        ? '0'
        : costVal.toStringAsFixed(costVal == costVal.roundToDouble() ? 0 : 2),
  );
  final notesController = TextEditingController(
    text: existingProduct?.notes ?? initialNotes ?? '',
  );
  final formKey = GlobalKey<FormState>();
  String? photoPath = existingProduct?.imagePath ?? initialImagePath;
  var scanningCode = false;

  final resolvedTitle = title ??
      switch (effectiveKind) {
        RegisterProductKind.priceTag => 'Register from price tag',
        RegisterProductKind.catalog => 'Add product',
        RegisterProductKind.edit => 'Edit product',
        RegisterProductKind.openItem => 'Open / loose item',
        RegisterProductKind.unknownBarcode => 'Register for this store',
      };

  final bodyText = headline ??
      switch (effectiveKind) {
        RegisterProductKind.priceTag =>
          'No product code on package. Price was read from the label — '
              'confirm details, name the item, and take a photo for the catalog '
              '(helps object detection training later).',
        RegisterProductKind.catalog =>
          'Add to this store’s catalog. Scan a barcode if you have one, '
              'take a product photo, and set prices.',
        RegisterProductKind.edit =>
          'Update catalog fields for this product. Barcode stays the same '
              'so cart and history keep matching.',
        RegisterProductKind.openItem =>
          'Loose produce, open packs, or items with no barcode/price tag. '
              'Enter a name and selling price (weight/amount as you sell it). '
              'Optional photo and code.',
        RegisterProductKind.unknownBarcode =>
          'Code not in this store’s catalog:\n${codeSeedNonEmpty ?? ''}\n\n'
              'Prices are store-specific — add a photo of the item if you can.',
      };

  final saveLabel = confirmLabel ??
      switch (effectiveKind) {
        RegisterProductKind.catalog => 'Save & add another',
        RegisterProductKind.edit => 'Save product',
        _ => 'Save & add',
      };

  final lockBarcode = effectiveKind == RegisterProductKind.edit ||
      (effectiveKind == RegisterProductKind.unknownBarcode &&
          codeSeedNonEmpty != null);

  final showEditableBarcode = !lockBarcode &&
      (effectiveKind == RegisterProductKind.catalog ||
          effectiveKind == RegisterProductKind.openItem ||
          effectiveKind == RegisterProductKind.priceTag ||
          effectiveKind == RegisterProductKind.unknownBarcode);

  final resolvedStoreId = storeId ?? existingProduct?.storeId;
  String? selectedVendorId = existingProduct?.vendorIds?.isNotEmpty == true ? existingProduct!.vendorIds!.first : null;
  List<Vendor> vendorsList = [];
  bool vendorsLoaded = false;

  try {
    return await showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!vendorsLoaded && resolvedStoreId != null && resolvedStoreId.isNotEmpty) {
              vendorsLoaded = true;
              locator<FirestoreService>().fetchVendors(storeId: resolvedStoreId).then((vs) {
                if (ctx.mounted) {
                  setDialogState(() {
                    vendorsList = vs;
                    if (selectedVendorId != null && !vs.any((v) => v.id == selectedVendorId)) {
                      selectedVendorId = null;
                    }
                  });
                }
              });
            }

            Future<void> scanBarcodeIntoField() async {
              if (scanningCode) return;
              setDialogState(() => scanningCode = true);
              try {
                final code = await locator<ScannerService>().scan();
                if (code != null && code.trim().isNotEmpty) {
                  setDialogState(() {
                    barcodeController.text = code.trim();
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Scan failed: $e')),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => scanningCode = false);
                }
              }
            }

            return AlertDialog(
              key: AppKeys.registerUnknownProductDialog,
              title: Text(resolvedTitle),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        bodyText,
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      if (lockBarcode && codeSeedNonEmpty != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Barcode: $codeSeedNonEmpty',
                          style: Theme.of(ctx).textTheme.labelSmall,
                        ),
                      ],
                      if (effectiveKind == RegisterProductKind.priceTag &&
                          codeSeedNonEmpty != null &&
                          !lockBarcode) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Catalog id: $codeSeedNonEmpty',
                          style: Theme.of(ctx).textTheme.labelSmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      ProductPhotoCapture(
                        photoPath: photoPath,
                        onPhotoChanged: (path) {
                          setDialogState(() => photoPath = path);
                        },
                        onProductNameParsed: (name) {
                          if (name.isNotEmpty) {
                            setDialogState(() => nameController.text = name);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: AppKeys.registerProductNameInput,
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product name *',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name required'
                            : null,
                      ),
                      if (showEditableBarcode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: AppKeys.registerProductBarcodeInput,
                          controller: barcodeController,
                          decoration: InputDecoration(
                            labelText: effectiveKind ==
                                    RegisterProductKind.openItem
                                ? 'Barcode (optional)'
                                : 'Barcode / code',
                            hintText: effectiveKind ==
                                    RegisterProductKind.openItem
                                ? 'Leave empty → auto OPEN id'
                                : 'Scan or type',
                            suffixIcon: IconButton(
                              key: AppKeys.registerProductScanBarcodeButton,
                              tooltip: 'Scan barcode',
                              onPressed:
                                  scanningCode ? null : scanBarcodeIntoField,
                              icon: scanningCode
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_scanner_rounded),
                            ),
                          ),
                          validator: (v) {
                            if (effectiveKind == RegisterProductKind.openItem ||
                                effectiveKind == RegisterProductKind.priceTag ||
                                effectiveKind == RegisterProductKind.catalog) {
                              return null;
                            }
                            if (v == null || v.trim().isEmpty) {
                              return 'Barcode required';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: AppKeys.registerProductPriceInput,
                        controller: priceController,
                        decoration: InputDecoration(
                          labelText: 'Selling price (Rs.) *',
                          hintText: effectiveKind == RegisterProductKind.openItem
                              ? 'Price for this sale / pack / weight'
                              : null,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        key: AppKeys.registerProductNotesInput,
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText:
                              effectiveKind == RegisterProductKind.openItem
                                  ? 'Notes (weight / unit)'
                                  : 'Notes (expiry / OCR text)',
                          hintText: effectiveKind == RegisterProductKind.openItem
                              ? 'e.g. 1.2 kg tomatoes, loose'
                              : 'Optional — kept for catalog & training',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Vendor (optional)',
                          isDense: true,
                        ),
                        value: selectedVendorId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...vendorsList.map(
                            (v) => DropdownMenuItem<String>(
                              value: v.id,
                              child: Text(v.name),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedVendorId = val);
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
                  child: Text(
                    effectiveKind == RegisterProductKind.catalog
                        ? 'Done'
                        : effectiveKind == RegisterProductKind.edit
                            ? 'Cancel'
                            : 'Skip',
                  ),
                ),
                FilledButton(
                  key: AppKeys.registerProductSaveButton,
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final name = nameController.text.trim();
                    final selling = double.parse(priceController.text.trim());
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
                    final notes = notesController.text.trim();

                    var code = barcodeController.text.trim();
                    if (code.isEmpty) {
                      if (lockBarcode && codeSeedNonEmpty != null) {
                        code = codeSeedNonEmpty;
                      } else {
                        final prefix = switch (effectiveKind) {
                          RegisterProductKind.openItem => 'OPEN_',
                          RegisterProductKind.priceTag => 'NOCODE_',
                          RegisterProductKind.catalog => 'NOCODE_',
                          RegisterProductKind.edit => 'NOCODE_',
                          RegisterProductKind.unknownBarcode => 'NOCODE_',
                        };
                        code =
                            '$prefix${DateTime.now().millisecondsSinceEpoch}';
                      }
                    }

                    if (existingProduct != null) {
                      code = existingProduct.barcode.isNotEmpty
                          ? existingProduct.barcode
                          : existingProduct.id;
                    }

                    final capturedPhoto = photoPath;
                    String? storedImage = capturedPhoto;
                    // Only re-copy when path looks like a new capture (or always persist).
                    if (capturedPhoto != null &&
                        resolvedStoreId != null &&
                        resolvedStoreId.isNotEmpty &&
                        capturedPhoto != existingProduct?.imagePath) {
                      storedImage = await persistProductImage(
                        sourcePath: capturedPhoto,
                        storeId: resolvedStoreId,
                        barcode: code,
                      );
                    }

                    final product = Product(
                      id: existingProduct?.id ?? code,
                      name: name,
                      barcode: code,
                      sellingPrice: selling,
                      costPrice: cost,
                      markup: markup,
                      storeId: resolvedStoreId,
                      imagePath: storedImage,
                      notes: notes.isEmpty ? null : notes,
                      vendorIds: selectedVendorId != null ? [selectedVendorId!] : null,
                    );
                    try {
                      await locator<FirestoreService>().saveProduct(
                        product,
                        storeId: resolvedStoreId,
                        businessId: businessId,
                        syncToBusiness: true,
                      );
                      
                      if (effectiveKind == RegisterProductKind.catalog) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Saved: ${product.name}')),
                          );
                          setDialogState(() {
                            nameController.clear();
                            barcodeController.clear();
                            priceController.clear();
                            costController.clear();
                            notesController.clear();
                            photoPath = null;
                            scanningCode = false;
                            selectedVendorId = null;
                          });
                        }
                      } else {
                        if (ctx.mounted) Navigator.of(ctx).pop(product);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  },
                  child: Text(saveLabel),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      barcodeController.dispose();
      priceController.dispose();
      costController.dispose();
      notesController.dispose();
    });
  }
}
