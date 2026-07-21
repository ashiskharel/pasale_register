import 'dart:async';
import 'package:flutter/material.dart';

import '../models/vendor_invoice.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';

/// Vendor home: stores in area, items sold, inventory level alerts.
class VendorStoresScreen extends StatefulWidget {
  const VendorStoresScreen({super.key});

  @override
  State<VendorStoresScreen> createState() => _VendorStoresScreenState();
}

class _VendorStoresScreenState extends State<VendorStoresScreen> {
  String? _vendorPhone;
  bool _loading = true;
  List<Map<String, dynamic>>? _stores;
  StreamSubscription? _sub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await locator<SessionService>().load();
    if (!mounted) return;
    final vendorPhone = session.phone;
    _vendorPhone = vendorPhone;
    if (vendorPhone != null && vendorPhone.isNotEmpty) {
      final fs = locator<FirestoreService>();
      _sub = fs.streamStoresForVendor(vendorPhone: vendorPhone).listen(
        (stores) {
          if (mounted) setState(() => _stores = stores);
        },
        onError: (e) {
          if (mounted) setState(() => _error = e.toString());
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
    super.dispose();
  }

  Future<void> _showSendInvoiceDialog(String storeId, String storeName) async {
    final totalController = TextEditingController();
    final itemsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Invoice to $storeName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalController,
                decoration: const InputDecoration(
                    labelText: 'Total Amount (Rs)', prefixText: 'Rs. '),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: itemsController,
                decoration: const InputDecoration(
                  labelText: 'Items (comma separated)',
                  hintText: 'e.g. 10x Rice, 5x Oil',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final totalStr = totalController.text.trim();
              final itemsStr = itemsController.text.trim();
              if (totalStr.isEmpty || itemsStr.isEmpty) return;

              final total = double.tryParse(totalStr);
              if (total == null) return;

              final items = itemsStr
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final session = await locator<SessionService>().load();
              final invoice = VendorInvoice(
                id: '',
                vendorUid: session.uid ?? '',
                vendorName:
                    session.displayName ?? _vendorPhone ?? 'Unknown Vendor',
                storeId: storeId,
                issuedAt: DateTime.now(),
                dueDate: DateTime.now().add(const Duration(days: 30)),
                totalAmount: total,
                lineItems: items,
                status: 'pending',
              );

              await locator<FirestoreService>()
                  .saveVendorInvoice(invoice, storeId: storeId);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice sent successfully!')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vendorPhone == null || _vendorPhone!.isEmpty) {
      return const Center(
          child: Text('No phone number found in session. Please log in.'));
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_stores == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stores = _stores!;
    if (stores.isEmpty) {
      return const Center(
          child: Text('You are not currently linked to any stores.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        final storeName = store['name'] as String? ?? 'Unknown Store';
        final storeId = store['storeId'] as String? ?? '';

        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.storefront),
            title: Text(storeName),
            subtitle: const Text('Store connected'),
            children: [
              OverflowBar(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      locator<SessionService>().setActiveStore(
                          storeId: storeId, storeName: storeName);
                      _showSendInvoiceDialog(storeId, storeName);
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send Invoice'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Chat with $storeName')),
                      );
                    },
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
