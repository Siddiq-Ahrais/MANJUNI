import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiService {
  // Status koneksi: null = belum dicek, true = online (terhubung ke localhost), false = offline
  static final ValueNotifier<bool?> isConnectedNotifier = ValueNotifier<bool?>(null);
  static final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> dataChangedNotifier = ValueNotifier<int>(0); // Triggers UI refresh across tabs

  // Fallback initial products
  static final List<Map<String, dynamic>> _fallbackProducts = [];

  // Fallback initial transactions (empty for guest mode)
  static final List<Map<String, dynamic>> _fallbackTransactions = [];

  // Fallback initial customers (empty for guest mode)
  static final List<Map<String, dynamic>> _fallbackCustomers = [];

  static void resetAllData() {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    _fallbackCustomers.clear();
    dataChangedNotifier.value++;
  }

  /// Ambil daftar pelanggan
  static Future<List<Map<String, dynamic>>> getCustomers() async {
    return List<Map<String, dynamic>>.from(_fallbackCustomers);
  }

  /// Tambah pelanggan baru
  static Future<bool> addCustomer({required String name, String? phone}) async {
    _fallbackCustomers.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name.trim(),
      'phone': phone ?? '',
    });
    dataChangedNotifier.value++;
    return true;
  }

  /// Uji koneksi ke endpoint test.php di localhost
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final uri = Uri.parse(ApiConfig.testUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isConnectedNotifier.value = true;
        lastErrorNotifier.value = null;
        return {
          'success': true,
          'message': data['message'] ?? 'Terhubung ke server localhost!',
          'data': data,
        };
      } else {
        isConnectedNotifier.value = false;
        final msg = 'Server merespon error code: ${res.statusCode}';
        lastErrorNotifier.value = msg;
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      isConnectedNotifier.value = false;
      final msg = 'Tidak dapat menghubungi ${ApiConfig.baseUrl}: $e';
      lastErrorNotifier.value = msg;
      return {'success': false, 'message': msg};
    }
  }

  /// Ambil daftar produk dari backend localhost atau fallback
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final uri = Uri.parse(ApiConfig.produkUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'success' && body['data'] is List) {
          isConnectedNotifier.value = true;
          final List list = body['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        }
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }
    return List<Map<String, dynamic>>.from(_fallbackProducts);
  }

  /// Tambah produk baru ke backend localhost atau memori lokal
  static Future<bool> addProduct({
    required String name,
    required int price,
    required int stock,
    required String unit,
    String? category,
    int? costPrice,
    int? minStock,
    String? barcode,
    String? weight, // Tambahan berat
  }) async {
    final effectiveCategory = (category != null && category.trim().isNotEmpty)
        ? category.trim()
        : 'Umum';
    final effectiveMinStock = minStock ?? 5;
    final effectiveCostPrice = costPrice ?? (price > 0 ? (price * 0.8).toInt() : 0);
    final effectiveBarcode = barcode?.trim() ?? '';
    final effectiveWeight = weight?.trim() ?? '';

    try {
      final uri = Uri.parse(ApiConfig.produkUrl);
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'price': price,
              'selling_price': price,
              'cost_price': effectiveCostPrice,
              'stock': stock,
              'min_stock': effectiveMinStock,
              'unit': unit,
              'category': effectiveCategory,
              'jenis': effectiveCategory,
              'barcode': effectiveBarcode,
              'weight': effectiveWeight,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        isConnectedNotifier.value = true;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Selalu simpan ke fallback lokal juga agar instan muncul di UI
    _fallbackProducts.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'price': price,
      'selling_price': price,
      'cost_price': effectiveCostPrice,
      'stock': stock,
      'min_stock': effectiveMinStock,
      'unit': unit,
      'category': effectiveCategory,
      'jenis': effectiveCategory,
      'barcode': effectiveBarcode,
      'weight': effectiveWeight,
      'low': stock <= effectiveMinStock,
    });
    dataChangedNotifier.value++; // Notify UI to refresh
    return true;
  }

  /// Hapus produk dari daftar
  static Future<bool> deleteProduct(dynamic id) async {
    _fallbackProducts.removeWhere((p) => p['id'] == id || p['name'] == id);
    dataChangedNotifier.value++;
    return true;
  }

  /// Ambil daftar transaksi dari backend localhost atau fallback
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final uri = Uri.parse(ApiConfig.transaksiUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'success' && body['data'] is List) {
          isConnectedNotifier.value = true;
          final List list = body['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        }
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }
    return List<Map<String, dynamic>>.from(_fallbackTransactions);
  }

  /// Catat transaksi baru ke backend localhost
  static Future<bool> createTransaction({
    required List<dynamic> cartItems,
    required String itemsSummary,
    required String paymentMethod,
    required int totalAmount,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.transaksiUrl);
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'items': itemsSummary,
              'method': paymentMethod,
              'amount': totalAmount,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isConnectedNotifier.value = true;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Deduct stock from fallbackProducts
    for (final item in cartItems) {
      final String name = (item.runtimeType.toString() == 'CartItem') ? (item as dynamic).name : (item['name'] as String? ?? '');
      final int qty = (item.runtimeType.toString() == 'CartItem') ? (item as dynamic).qty : ((item['qty'] as int?) ?? 1);

      final idx = _fallbackProducts.indexWhere((p) => (p['name'] as String).toLowerCase() == name.toLowerCase());
      if (idx != -1) {
        final currentStock = (_fallbackProducts[idx]['stock'] as int?) ?? 0;
        final newStock = (currentStock - qty).clamp(0, 999999);
        _fallbackProducts[idx]['stock'] = newStock;
        _fallbackProducts[idx]['low'] = newStock <= 5;
      }
    }

    // Fallback lokal jika offline
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    final serializedItems = cartItems.map((i) {
      if (i.runtimeType.toString() == 'CartItem') return (i as dynamic).toMap();
      return Map<String, dynamic>.from(i as Map);
    }).toList();

    _fallbackTransactions.insert(0, {
      'id': 'TRX-0${_fallbackTransactions.length + 1}',
      'time': timeStr,
      'items': itemsSummary,
      'method': paymentMethod,
      'amount': totalAmount,
      'synced': paymentMethod.toLowerCase() == 'tunai',
      'cartItems': serializedItems,
    });
    dataChangedNotifier.value++; // Notify UI to refresh
    return true;
  }

  /// Ambil data statistik ringkasan dashboard
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final uri = Uri.parse(ApiConfig.dashboardUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'success' && body['data'] is Map) {
          final data = body['data'];
          if ((data['omzet'] as int? ?? 0) > 0 || (data['total_transaksi'] as int? ?? 0) > 0) {
            isConnectedNotifier.value = true;
            return Map<String, dynamic>.from(data);
          }
        }
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Calculate dynamically from local fallback data (guest starts at 0)
    int omzet = _fallbackTransactions.fold(0, (sum, t) => sum + ((t['amount'] as int?) ?? 0));
    int totalTrx = _fallbackTransactions.length;
    int totalProduk = _fallbackProducts.length;
    int stokMenipis = _fallbackProducts.where((p) => ((p['stock'] as int?) ?? 0) <= 5).length;

    Map<String, int> productSales = {};
    for (final t in _fallbackTransactions) {
      final items = t['cartItems'] as List? ?? [];
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = (item['qty'] as int?) ?? 1;
        if (name.isNotEmpty) {
          productSales[name] = (productSales[name] ?? 0) + qty;
        }
      }
    }

    String produkTerlaris = '-';
    if (productSales.isNotEmpty) {
      final sorted = productSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      produkTerlaris = sorted.first.key;
    }

    return {
      'omzet': omzet,
      'total_transaksi': totalTrx,
      'produk_terlaris': produkTerlaris,
      'stok_menipis': stokMenipis,
      'total_produk': totalProduk,
    };
  }
}
