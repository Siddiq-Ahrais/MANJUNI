import 'package:flutter/foundation.dart';

class CartItem {
  final String name;
  final int price;
  final String unit;
  int qty;

  CartItem({
    required this.name,
    required this.price,
    required this.unit,
    this.qty = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'unit': unit,
      'qty': qty,
    };
  }
}

class CartService {
  // Initial cart populated as empty for guest mode
  static final ValueNotifier<List<CartItem>> cartNotifier = ValueNotifier<List<CartItem>>([]);

  static int get totalCount => cartNotifier.value.fold(0, (sum, item) => sum + item.qty);
  static int get typesCount => cartNotifier.value.length;
  static int get subtotal => cartNotifier.value.fold(0, (sum, item) => sum + item.price * item.qty);

  static void addItem(String name, int price, String unit) {
    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere((item) => item.name.toLowerCase() == name.toLowerCase());
    if (idx != -1) {
      list[idx].qty += 1;
    } else {
      list.add(CartItem(name: name, price: price, unit: unit, qty: 1));
    }
    cartNotifier.value = list;
  }

  static void updateQty(int index, int delta) {
    if (index < 0 || index >= cartNotifier.value.length) return;
    final list = List<CartItem>.from(cartNotifier.value);
    final newQty = list[index].qty + delta;
    if (newQty <= 0) {
      list.removeAt(index);
    } else {
      list[index].qty = newQty;
    }
    cartNotifier.value = list;
  }

  static void removeItem(int index) {
    if (index < 0 || index >= cartNotifier.value.length) return;
    final list = List<CartItem>.from(cartNotifier.value);
    list.removeAt(index);
    cartNotifier.value = list;
  }

  static void clear() {
    cartNotifier.value = [];
  }
}
