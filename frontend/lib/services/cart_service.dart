import 'package:flutter/foundation.dart';

class CartItem {
  final dynamic productId;
  final String name;
  final int price;
  final int costPrice;
  final String unit;
  final int? maxStock;
  final String? image;
  final String? category;
  int qty;

  CartItem({
    this.productId,
    required this.name,
    required this.price,
    this.costPrice = 0,
    required this.unit,
    this.maxStock,
    this.image,
    this.category,
    this.qty = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'product_id': productId,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'unit': unit,
      if (maxStock != null) 'max_stock': maxStock,
      if (image != null && image!.isNotEmpty) 'image': image,
      if (category != null && category!.isNotEmpty) 'category': category,
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

  static bool _matchesProduct(CartItem item, {dynamic productId, required String name}) {
    if (productId != null && item.productId != null) {
      if (item.productId.toString() == productId.toString()) return true;
    }
    return item.name.trim().toLowerCase() == name.trim().toLowerCase();
  }

  /// Jumlah kuantitas produk tertentu yang sedang berada di keranjang.
  static int qtyForProduct({dynamic productId, required String name}) {
    return cartNotifier.value
        .where((item) => _matchesProduct(item, productId: productId, name: name))
        .fold<int>(0, (sum, item) => sum + item.qty);
  }

  /// Sinkronkan batas stok (`maxStock`) item keranjang terhadap daftar produk terbaru.
  static void syncStockLimits(List<Map<String, dynamic>> products) {
    if (cartNotifier.value.isEmpty || products.isEmpty) return;
    bool changed = false;
    final updated = cartNotifier.value.map((item) {
      final match = products.firstWhere(
        (p) {
          final pId = p['id'];
          if (pId != null && item.productId != null && pId.toString() == item.productId.toString()) {
            return true;
          }
          return (p['name']?.toString().trim().toLowerCase() ?? '') ==
              item.name.trim().toLowerCase();
        },
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && match['stock'] != null) {
        final int latestStock = (match['stock'] as num).toInt();
        if (item.maxStock != latestStock) {
          changed = true;
          return CartItem(
            productId: match['id'] ?? item.productId,
            name: item.name,
            price: item.price,
            costPrice: item.costPrice,
            unit: item.unit,
            maxStock: latestStock,
            image: item.image,
            category: item.category,
            qty: item.qty,
          );
        }
      }
      return item;
    }).toList();
    if (changed) {
      cartNotifier.value = updated;
    }
  }

  /// Menambahkan item ke keranjang dengan validasi stok.
  /// Mengembalikan `false` jika stok habis atau jumlah melebihi `maxStock`.
  static bool addItem(
    String name,
    int price,
    String unit, {
    int? maxStock,
    dynamic productId,
    int costPrice = 0,
    String? image,
    String? category,
  }) {
    if (maxStock != null && maxStock <= 0) {
      return false;
    }

    final normalizedName = name.trim();
    final normalizedUnit = unit.trim().isNotEmpty ? unit.trim() : 'pcs';
    final list = List<CartItem>.from(cartNotifier.value);
    final idx = list.indexWhere(
      (item) => _matchesProduct(item, productId: productId, name: normalizedName),
    );
    if (idx != -1) {
      final effectiveMax = maxStock ?? list[idx].maxStock;
      if (effectiveMax != null && list[idx].qty + 1 > effectiveMax) {
        return false;
      }
      list[idx] = CartItem(
        productId: productId ?? list[idx].productId,
        name: list[idx].name,
        price: price > 0 ? price : list[idx].price,
        costPrice: costPrice > 0 ? costPrice : list[idx].costPrice,
        unit: normalizedUnit,
        maxStock: effectiveMax,
        image: (image != null && image.isNotEmpty) ? image : list[idx].image,
        category: (category != null && category.isNotEmpty) ? category : list[idx].category,
        qty: list[idx].qty + 1,
      );
    } else {
      list.add(CartItem(
        productId: productId,
        name: normalizedName,
        price: price,
        costPrice: costPrice,
        unit: normalizedUnit,
        maxStock: maxStock,
        image: image,
        category: category,
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
        costPrice: current.costPrice,
        unit: current.unit,
        maxStock: effectiveMax,
        image: current.image,
        category: current.category,
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
