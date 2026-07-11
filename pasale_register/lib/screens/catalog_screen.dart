import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';
import '../models/product.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';
import '../services/cart_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _markupController = TextEditingController();

  String _status = '';
  bool _showAddForm = false;

  void _saveProduct() async {
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final sellingPriceStr = _sellingPriceController.text.trim();
    final costPriceStr = _costPriceController.text.trim();
    final markupStr = _markupController.text.trim();

    if (name.isEmpty || barcode.isEmpty) {
      setState(() {
        _status = 'Error: Name and Barcode required';
      });
      return;
    }

    double? sellingPrice;
    double? costPrice;
    double? markup;

    if (sellingPriceStr.isNotEmpty) {
      sellingPrice = double.tryParse(sellingPriceStr);
      if (sellingPrice == null) {
        setState(() => _status = 'Error: Prices and markup must be valid numbers');
        return;
      }
    } else {
      sellingPrice = 0.0;
    }

    if (costPriceStr.isNotEmpty) {
      costPrice = double.tryParse(costPriceStr);
      if (costPrice == null) {
        setState(() => _status = 'Error: Prices and markup must be valid numbers');
        return;
      }
    } else {
      costPrice = 0.0;
    }

    if (markupStr.isNotEmpty) {
      markup = double.tryParse(markupStr);
      if (markup == null) {
        setState(() => _status = 'Error: Prices and markup must be valid numbers');
        return;
      }
    } else {
      markup = 0.0;
    }

    if (sellingPrice < 0.0 || costPrice < 0.0 || markup < 0.0) {
      setState(() {
        _status = 'Error: Prices and markup must be non-negative';
      });
      return;
    }

    if (sellingPrice < costPrice) {
      setState(() {
        _status = 'Error: Selling price cannot be less than cost price';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');

    final product = Product(
      id: barcode, // using barcode as id
      name: name,
      barcode: barcode,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      markup: markup,
      storeId: storeId,
    );

    try {
      await locator<FirestoreService>().saveProduct(product, storeId: storeId);
      setState(() {
        _status = 'Product Saved: $name';
        _showAddForm = false;
        _nameController.clear();
        _barcodeController.clear();
        _sellingPriceController.clear();
        _costPriceController.clear();
        _markupController.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _markupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Catalog')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              key: AppKeys.productSearchInput,
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Products',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),
          ElevatedButton(
            key: AppKeys.addProductButton,
            onPressed: () {
              setState(() {
                _showAddForm = !_showAddForm;
              });
            },
            child: Text(_showAddForm ? 'Hide Form' : 'Add Product Manually'),
          ),
          if (_showAddForm) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  TextField(
                    key: AppKeys.productNameInput,
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name'),
                  ),
                  TextField(
                    key: AppKeys.productBarcodeInput,
                    controller: _barcodeController,
                    decoration: const InputDecoration(labelText: 'Barcode'),
                  ),
                  TextField(
                    key: AppKeys.productSellingPriceInput,
                    controller: _sellingPriceController,
                    decoration: const InputDecoration(labelText: 'Selling Price'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    key: AppKeys.productCostPriceInput,
                    controller: _costPriceController,
                    decoration: const InputDecoration(labelText: 'Cost Price'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    key: AppKeys.productMarkupInput,
                    controller: _markupController,
                    decoration: const InputDecoration(labelText: 'Markup %'),
                    keyboardType: TextInputType.number,
                  ),
                  ElevatedButton(
                    key: AppKeys.saveProductButton,
                    onPressed: _saveProduct,
                    child: const Text('Save Product'),
                  ),
                ],
              ),
            ),
          ],
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _status,
                key: AppKeys.statusText,
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          Expanded(
            child: FutureBuilder<String?>(
              future: SharedPreferences.getInstance()
                  .then((p) => p.getString('storeId')),
              builder: (context, storeSnap) {
                final storeId = storeSnap.data;
                return StreamBuilder<List<Product>>(
              stream: locator<FirestoreService>().streamCatalog(storeId: storeId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _searchController.text.toLowerCase().trim();
                final products = snapshot.data!.where((p) {
                  return p.name.toLowerCase().contains(query) ||
                      p.barcode.toLowerCase().contains(query);
                }).toList();

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      key: ValueKey('catalog_item_${product.barcode}'),
                      title: Text(product.name),
                      subtitle: Text(
                        'Barcode: ${product.barcode}'
                        '${product.storeId != null ? ' · store' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Rs. ${product.sellingPrice}'),
                          const SizedBox(width: 8),
                          IconButton(
                            key: ValueKey('add_to_cart_${product.barcode}'),
                            icon: const Icon(
                              Icons.add_shopping_cart,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              locator<CartService>().addProduct(product);
                              setState(() {
                                _status = 'Added ${product.name} to cart';
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
