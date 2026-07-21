import 'dart:async';
import 'package:flutter/material.dart';

import '../constants/keys.dart';
import '../models/vendor.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';

/// Store owner: manage vendors and reorder low-stock items.
class VendorsManageScreen extends StatefulWidget {
  const VendorsManageScreen({super.key});

  @override
  State<VendorsManageScreen> createState() => _VendorsManageScreenState();
}

class _VendorsManageScreenState extends State<VendorsManageScreen> {
  String? _storeId;
  bool _loading = true;
  List<Vendor>? _vendors;
  List<Product>? _products;
  StreamSubscription? _sub;
  StreamSubscription? _prodSub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await locator<SessionService>().load();
    if (!mounted) return;
    final storeId = session.storeId;
    _storeId = storeId;
    if (storeId != null && storeId.isNotEmpty) {
      final fs = locator<FirestoreService>();
      try {
        final initialVendors = await fs.fetchVendors(storeId: storeId).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Timed out fetching vendors.'),
        );
        if (mounted) setState(() => _vendors = initialVendors);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      }
      
      _sub = fs.streamVendors(storeId: storeId).listen(
        (vendors) {
          if (mounted) setState(() => _vendors = vendors);
        },
        onError: (e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );

      _prodSub = fs.streamCatalog(storeId: storeId).listen(
        (products) {
          if (mounted) setState(() => _products = products);
        },
      );
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _prodSub?.cancel();
    super.dispose();
  }

  Future<void> _showVendorDialog([Vendor? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final contactPersonController = TextEditingController(text: existing?.contactPerson ?? '');
    final phoneController = TextEditingController(
      text: existing?.salespersonPhones.isNotEmpty == true
          ? existing!.salespersonPhones.first
          : '',
    ); 

    final selectedProductIds = <String>{};
    if (existing != null && _products != null) {
      for (final p in _products!) {
        if (p.vendorIds?.contains(existing.id) == true) {
          selectedProductIds.add(p.id);
        }
      }
    }
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Vendor' : 'Edit Vendor'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Vendor / Salesperson Name'),
                    ),
                    TextField(
                      controller: contactPersonController,
                      decoration:
                          const InputDecoration(labelText: 'Contact Person (Optional)'),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        helperText: 'Vendor will use this phone to log in',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    const Text('Linked Products', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_products == null || _products!.isEmpty)
                      const Text('No products found in store.', style: TextStyle(color: Colors.grey))
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _products!.length,
                          itemBuilder: (context, index) {
                            final p = _products![index];
                            final isSelected = selectedProductIds.contains(p.id);
                            return CheckboxListTile(
                              title: Text(p.name),
                              subtitle: Text(p.barcode.isEmpty ? 'No barcode' : p.barcode),
                              value: isSelected,
                              onChanged: (val) {
                                setStateDialog(() {
                                  if (val == true) {
                                    selectedProductIds.add(p.id);
                                  } else {
                                    selectedProductIds.remove(p.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  final vendorId = existing?.id ?? 'VEND_${DateTime.now().millisecondsSinceEpoch}';

                  final vendor = Vendor(
                    id: vendorId,
                    name: nameController.text.trim(),
                    storeId: _storeId!,
                    contactPerson: contactPersonController.text.trim().isEmpty
                        ? ''
                        : contactPersonController.text.trim(),
                    salespersonPhones: phoneController.text.trim().isEmpty
                        ? (existing?.salespersonPhones ?? [])
                        : [phoneController.text.trim()],
                  );

                  await locator<FirestoreService>()
                      .saveVendor(vendor, storeId: _storeId!);

                  // Update products
                  if (_products != null) {
                    for (final p in _products!) {
                      final wasSelected = p.vendorIds?.contains(vendorId) ?? false;
                      final isSelectedNow = selectedProductIds.contains(p.id);

                      if (wasSelected != isSelectedNow) {
                        final newVendorIds = List<String>.from(p.vendorIds ?? []);
                        if (isSelectedNow) {
                          newVendorIds.add(vendorId);
                        } else {
                          newVendorIds.remove(vendorId);
                        }
                        await locator<FirestoreService>().saveProduct(
                          p.copyWith(vendorIds: newVendorIds),
                          storeId: _storeId!,
                        );
                      }
                    }
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_storeId == null || _storeId!.isEmpty) {
      return const Scaffold(body: Center(child: Text('No store selected.')));
    }

    if (_error != null) {
      return Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showVendorDialog(),
          child: const Icon(Icons.add),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading vendors:\n$_error\n\n(Did you forget to deploy firestore.rules?)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (_vendors == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final vendors = _vendors!;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVendorDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        key: AppKeys.vendorsScreen,
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Colors.orange.shade50,
            child: const ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
              title: Text('Low stock reorders'),
              subtitle: Text(
                'Order via invoice scan or from items running low below.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (vendors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No vendors added yet. Tap + to add one.',
                  textAlign: TextAlign.center),
            ),
          ...vendors.map((v) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(v.name),
                subtitle: Text(
                  '${v.contactPerson.isNotEmpty ? v.contactPerson + ' • ' : ''}${v.salespersonPhones.join(', ')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Vendor',
                  onPressed: () => _showVendorDialog(v),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
