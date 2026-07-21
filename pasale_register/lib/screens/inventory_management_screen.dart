import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import 'physical_audit_screen.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  String? _storeId;
  List<Product> _lowStockProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    if (storeId == null) return;
    
    setState(() {
      _storeId = storeId;
    });

    locator<FirestoreService>()
        .streamCatalog(storeId: storeId)
        .listen((products) {
      if (!mounted) return;
      setState(() {
        _lowStockProducts = products.where((p) => p.quantity <= 5).toList()
          ..sort((a, b) => a.quantity.compareTo(b.quantity));
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Inventory Audit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan a barcode to quickly update the physical stock count of a product.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhysicalAuditScreen(storeId: _storeId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Start Audit'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Low Stock Alerts',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (_lowStockProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('All products are sufficiently stocked.'),
          )
        else
          ..._lowStockProducts.map((p) {
            return ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              title: Text(p.name),
              subtitle: Text(p.barcode),
              trailing: Text(
                'Qty: ${p.quantity.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            );
          }),
      ],
    );
  }
}
