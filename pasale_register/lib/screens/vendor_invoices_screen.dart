import 'dart:async';
import 'package:flutter/material.dart';

import '../models/vendor_invoice.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';

class VendorInvoicesScreen extends StatefulWidget {
  const VendorInvoicesScreen({super.key});

  @override
  State<VendorInvoicesScreen> createState() => _VendorInvoicesScreenState();
}

class _VendorInvoicesScreenState extends State<VendorInvoicesScreen> {
  String? _storeId;
  bool _loading = true;
  List<VendorInvoice>? _invoices;
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
    final storeId = session.storeId;
    final uid = session.uid;
    _storeId = storeId;
    
    if (storeId != null && storeId.isNotEmpty) {
      final fs = locator<FirestoreService>();
      _sub = fs.streamVendorInvoices(storeId: storeId, vendorUid: uid).listen(
        (invoices) {
          if (mounted) setState(() => _invoices = invoices);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storeId == null || _storeId!.isEmpty) {
      return const Center(
          child: Text('Please select a store to view invoices.'));
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_invoices == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final invoices = _invoices!;
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        return Card(
          child: ListTile(
            leading: Icon(
              inv.status == 'paid'
                  ? Icons.check_circle
                  : Icons.pending_actions,
              color: inv.status == 'paid' ? Colors.green : Colors.orange,
            ),
            title: Text('Invoice from ${inv.vendorName}'),
            subtitle: Text(
                'Total: Rs. ${inv.totalAmount.toStringAsFixed(2)} - ${inv.status.toUpperCase()}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show details
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Invoice Details'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${inv.id}'),
                      Text(
                          'Date: ${inv.issuedAt.toString().split('.')[0]}'),
                      Text(
                          'Total: Rs. ${inv.totalAmount.toStringAsFixed(2)}'),
                      Text('Status: ${inv.status.toUpperCase()}'),
                      const Divider(),
                      const Text('Items:'),
                      ...inv.lineItems.map((e) => Text('• $e')),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
