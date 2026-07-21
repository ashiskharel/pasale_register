import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/keys.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../widgets/register_product_dialog.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  String _status = '';
  String? _storeId;
  String? _businessId;
  bool _storeReady = false;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _storeId = prefs.getString('storeId');
      _businessId = prefs.getString('businessId');
      _storeReady = true;
    });
  }

  Future<void> _openAddProduct() async {
    final product = await showRegisterProductDialog(
      context: context,
      kind: RegisterProductKind.catalog,
      storeId: _storeId,
      businessId: _businessId,
    );
    if (!mounted) return;
    if (product != null) {
      setState(() => _status = 'Product Saved: ${product.name}');
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final updated = await showRegisterProductDialog(
      context: context,
      kind: RegisterProductKind.edit,
      storeId: _storeId ?? product.storeId,
      businessId: _businessId,
      existingProduct: product,
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _status = 'Product updated: ${updated.name}');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: AppKeys.productSearchInput,
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search products',
              hintText: 'Name or barcode',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: AppKeys.addProductButton,
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            ),
          ),
        ),
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _status,
              key: AppKeys.statusText,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: !_storeReady
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<Product>>(
                  stream: locator<FirestoreService>().streamCatalog(
                    storeId: _storeId,
                    businessId: _businessId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final query = _searchController.text.toLowerCase().trim();
                    var products = snapshot.data!;
                    
                    if (query.isNotEmpty) {
                      products = products.where((p) {
                        return p.name.toLowerCase().contains(query) ||
                            p.barcode.toLowerCase().contains(query);
                      }).take(50).toList();
                    } else {
                      // Show up to 20 most recently added products by default
                      products = products.reversed.take(20).toList();
                    }

                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          query.isEmpty
                              ? 'No products yet.\nAdd one or scan at checkout.'
                              : 'No matches for “$query”',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return Card(
                          child: ListTile(
                            key: ValueKey('catalog_item_${product.barcode}'),
                            onTap: () => _openEditProduct(product),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                shape: BoxShape.circle,
                                image: product.imagePath != null && product.imagePath!.isNotEmpty
                                    ? DecorationImage(
                                        image: (product.imagePath!.startsWith('http') 
                                            ? NetworkImage(product.imagePath!) 
                                            : FileImage(File(product.imagePath!))) as ImageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: product.imagePath == null || product.imagePath!.isEmpty
                                  ? Icon(
                                      Icons.inventory_2_outlined,
                                      color: scheme.onPrimaryContainer,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            title: Text(product.name),
                            subtitle: Text(
                              '${product.barcode}'
                              '${product.storeId != null ? ' · store' : ''}'
                              ' · tap to edit',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rs. ${product.sellingPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton.filledTonal(
                                  key: ValueKey(
                                    'add_to_cart_${product.barcode}',
                                  ),
                                  tooltip: 'Add to cart',
                                  icon: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    locator<CartService>().addProduct(product);
                                    setState(() {
                                      _status =
                                          'Added ${product.name} to cart';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Product Catalog')),
      body: body,
    );
  }
}
