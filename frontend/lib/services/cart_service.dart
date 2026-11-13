import 'package:flutter/foundation.dart';

class CartItem {
  final dynamic productId;
  final String name;
  final int price;
  final String unit;
  final int? maxStock;
  int qty;

  CartItem({
    this.productId,
    required this.name,
    required this.price,
    required this.unit,
    this.maxStock,
    this.qty = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'product_id': productId,
      'name': name,
      'price': price,
      'unit': unit,
      if (maxStock != null) 'max_stock': maxStock,
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

  /// Menambahkan item ke keranjang dengan validasi stok.
  /// Mengembalikan `false` jika stok habis atau jumlah melebihi `maxStock`.
  static bool addItem(
    String name,
    int price,
    String unit, {
    int? maxStock,
    dynamic productId,
  }) {
    if (maxStock != null && maxStock <= 0) {
      return false;
    }

    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere((item) => item.name.toLowerCase() == name.toLowerCase());
    if (idx != -1) {
      final effectiveMax = maxStock ?? list[idx].maxStock;
      if (effectiveMax != null && list[idx].qty + 1 > effectiveMax) {
        return false;
      }
      list[idx] = CartItem(
        productId: productId ?? list[idx].productId,
        name: list[idx].name,
        price: list[idx].price,
        unit: list[idx].unit,
        maxStock: effectiveMax,
        qty: list[idx].qty + 1,
      );
    } else {
      list.add(CartItem(
        productId: productId,
        name: name,
        price: price,
        unit: unit,
        maxStock: maxStock,
        qty: 1,
      ));
    }
    cartNotifier.value = list;
    return true;
  }

  /// Mengubah jumlah item di keranjang dengan validasi batas stok.
  /// Mengembalikan `false` jika penambahan melebihi stok tersedia.
  static bool updateQty(int index, int delta, {int? maxStock}) {
    if (index < 0 || index >= cartNotifier.value.length) return false;
    final list = List<CartItem>.from(cartNotifier.value);
    final current = list[index];
    final newQty = current.qty + delta;
    final effectiveMax = maxStock ?? current.maxStock;

    if (delta > 0 && effectiveMax != null && newQty > effectiveMax) {
      return false;
    }

    if (newQty <= 0) {
      list.removeAt(index);
    } else {
      list[index] = CartItem(
        productId: current.productId,
        name: current.name,
        price: current.price,
        unit: current.unit,
        maxStock: effectiveMax,
        qty: newQty,
      );
    }
    cartNotifier.value = list;
    return true;
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
