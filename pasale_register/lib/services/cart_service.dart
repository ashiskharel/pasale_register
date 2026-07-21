import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _checkoutCompleted = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get checkoutCompleted => _checkoutCompleted;

  set checkoutCompleted(bool value) {
    _checkoutCompleted = value;
    notifyListeners();
  }

  double get totalPrice {
    return _items.fold(0.0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));
  }

  void addProduct(Product product) {
    _checkoutCompleted = false;
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_items[index].quantity < _items[index].product.quantity) {
        _items[index].quantity++;
        notifyListeners();
      }
    } else {
      if (product.quantity >= 1 || product.barcode.isEmpty) {
        _items.add(CartItem(product: product, quantity: 1));
        notifyListeners();
      }
    }
  }

  bool incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity >= _items[index].product.quantity && _items[index].product.barcode.isNotEmpty) {
        return false; // Max reached
      }
      _checkoutCompleted = false;
      _items[index].quantity++;
      notifyListeners();
      return true;
    }
    return false;
  }

  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _checkoutCompleted = false;
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _checkoutCompleted = false;
    notifyListeners();
  }
}
