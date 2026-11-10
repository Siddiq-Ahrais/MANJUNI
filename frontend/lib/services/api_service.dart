import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class ApiService {
  // Status koneksi: null = belum dicek, true = online (terhubung ke localhost), false = offline
  static final ValueNotifier<bool?> isConnectedNotifier = ValueNotifier<bool?>(null);
  static final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> dataChangedNotifier = ValueNotifier<int>(0); // Triggers UI refresh across tabs

  // Fallback initial products (sample minimalist catalog matching UI mockup)
  static final List<Map<String, dynamic>> _fallbackProducts = [
    {
      'id': 1,
      'name': 'PUMA Magnify Nitro 3',
      'brand': 'PUMA',
      'category': 'Footwear',
      'price': 130, // $130
      'cost_price': 85,
      'stock': 45,
      'min_stock': 8,
      'unit': 'pair',
      'sales': 62,
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=600&auto=format&fit=crop&q=80',
      'variants': [
        'https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=200&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=200&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=200&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1539185441755-769473a23570?w=200&auto=format&fit=crop&q=80',
      ],
      'revenue': 8060,
      'low': false,
    },
    {
      'id': 2,
      'name': 'New Balance 740',
      'brand': 'New Balance',
      'category': 'Footwear',
      'price': 90, // $90
      'cost_price': 55,
      'stock': 32,
      'min_stock': 6,
      'unit': 'pair',
      'sales': 56,
      'rating': 4.8,
      'image': 'https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&auto=format&fit=crop&q=80',
      'revenue': 5040,
      'low': false,
    },
    {
      'id': 3,
      'name': 'AirPods 3',
      'brand': 'Apple',
      'category': 'Electronics',
      'price': 150, // $150
      'cost_price': 100,
      'stock': 24,
      'min_stock': 5,
      'unit': 'unit',
      'sales': 43,
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=600&auto=format&fit=crop&q=80',
      'revenue': 6450,
      'low': false,
    },
    {
      'id': 4,
      'name': 'Salomon XA shoes',
      'brand': 'Salomon',
      'category': 'Footwear',
      'price': 100, // $100
      'cost_price': 65,
      'stock': 18,
      'min_stock': 5,
      'unit': 'pair',
      'sales': 39,
      'rating': 4.7,
      'image': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=80',
      'revenue': 3900,
      'low': false,
    },
    {
      'id': 5,
      'name': 'Nike Air Force 1',
      'brand': 'Nike',
      'category': 'Footwear',
      'price': 115, // $115
      'cost_price': 70,
      'stock': 28,
      'min_stock': 6,
      'unit': 'pair',
      'sales': 42,
      'rating': 4.8,
      'image': 'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=600&auto=format&fit=crop&q=80',
      'revenue': 4830,
      'low': false,
    },
    {
      'id': 6,
      'name': 'Sony WH-1000XM5',
      'brand': 'Sony',
      'category': 'Electronics',
      'price': 280, // $280
      'cost_price': 190,
      'stock': 15,
      'min_stock': 4,
      'unit': 'unit',
      'sales': 25,
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600&auto=format&fit=crop&q=80',
      'revenue': 7000,
      'low': false,
    },
    {
      'id': 7,
      'name': 'Apple Watch Series 9',
      'brand': 'Apple',
      'category': 'Electronics',
      'price': 399, // $399
      'cost_price': 290,
      'stock': 12,
      'min_stock': 3,
      'unit': 'unit',
      'sales': 19,
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop&q=80',
      'revenue': 7581,
      'low': false,
    },
    {
      'id': 8,
      'name': 'Essential Hoodie Mint',
      'brand': 'Essentials',
      'category': 'Fashion',
      'price': 30, // $30
      'cost_price': 16,
      'stock': 4, // low stock!
      'min_stock': 5,
      'unit': 'pcs',
      'sales': 48,
      'rating': 4.6,
      'image': 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=600&auto=format&fit=crop&q=80',
      'revenue': 1440,
      'low': true,
    },
    {
      'id': 9,
      'name': 'Glow Face Cream',
      'brand': 'BeautyLab',
      'category': 'Beauty',
      'price': 18, // $18
      'cost_price': 9,
      'stock': 3, // low stock!
      'min_stock': 5,
      'unit': 'jar',
      'sales': 34,
      'rating': 4.7,
      'image': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=600&auto=format&fit=crop&q=80',
      'revenue': 612,
      'low': true,
    },
  ];

  // Fallback initial transactions (matching mockup recent activities)
  static final List<Map<String, dynamic>> _fallbackTransactions = [
    {
      'id': 'TRX-1015',
      'customer': 'Daniel Cooper',
      'time': 'Just now',
      'items': 'Purchased Nike Air Max 90',
      'amount': 154,
      'method': 'Credit Card',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
      'synced': true,
    },
    {
      'id': 'TRX-1014',
      'customer': 'Sophie Bennett',
      'time': '25 mins ago',
      'items': 'Purchased Sony WH-1000XM5',
      'amount': 68,
      'method': 'Apple Pay',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
      'synced': true,
    },
    {
      'id': 'TRX-1013',
      'customer': 'Mia Anderson',
      'time': '1 hour ago',
      'items': 'Purchased Apple Watch Series 9',
      'amount': 243,
      'method': 'QRIS',
      'avatar': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&auto=format&fit=crop&q=80',
      'synced': true,
    },
    {
      'id': 'TRX-1012',
      'customer': 'Lucas Wright',
      'time': '3 hours ago',
      'items': 'Purchased PUMA Magnify Nitro 3',
      'amount': 130,
      'method': 'Debit',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100&auto=format&fit=crop&q=80',
      'synced': true,
    },
  ];

  static void resetAllData() {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    dataChangedNotifier.value++;
  }

  /// Uji koneksi ke endpoint REST API
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final uri = Uri.parse(ApiConfig.healthUrl);
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isConnectedNotifier.value = true;
        lastErrorNotifier.value = null;
        return {
          'success': true,
          'message': data['message'] ?? (data['status'] == 'ok' ? 'Terhubung ke REST API Server (v1)!' : 'Terhubung ke server!'),
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
      final uri = Uri.parse(ApiConfig.productsUrl);
      final res = await http
          .get(uri, headers: AuthService.authHeaders)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is List) {
          isConnectedNotifier.value = true;
          final List list = body['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        } else if (body is Map && body['status'] == 'success' && body['data'] is List) {
          isConnectedNotifier.value = true;
          final List list = body['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        } else if (body is List && body.isNotEmpty) {
          isConnectedNotifier.value = true;
          return List<Map<String, dynamic>>.from(
            body.map((e) => Map<String, dynamic>.from(e as Map)),
          );
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
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.productsUrl);
      final res = await http
          .post(
            uri,
            headers: AuthService.authHeaders,
            body: jsonEncode({
              'name': name,
              'price': price,
              'stock': stock,
              'unit': unit,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        isConnectedNotifier.value = true;
        return true;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Jika offline, simpan ke memori lokal
    _fallbackProducts.insert(0, {
      'id': _fallbackProducts.length + 1,
      'name': name,
      'price': price,
      'stock': stock,
      'unit': unit,
      'low': stock <= 5,
    });
    dataChangedNotifier.value++; // Notify UI to refresh
    return true;
  }

  /// Ambil daftar transaksi dari backend localhost atau fallback
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final uri = Uri.parse(ApiConfig.transactionsUrl);
      final res = await http
          .get(uri, headers: AuthService.authHeaders)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is List) {
          isConnectedNotifier.value = true;
          final List list = body['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        } else if (body is Map && body['status'] == 'success' && body['data'] is List) {
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
      final uri = Uri.parse(ApiConfig.transactionsUrl);
      final res = await http
          .post(
            uri,
            headers: AuthService.authHeaders,
            body: jsonEncode({
              'items': itemsSummary,
              'method': paymentMethod,
              'amount': totalAmount,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
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
      final res = await http
          .get(uri, headers: AuthService.authHeaders)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          isConnectedNotifier.value = true;
          if (body['today'] is Map) {
            return {
              'omzet': (body['today']['sales'] as num?)?.toInt() ?? 0,
              'total_transaksi': (body['today']['transactions'] as num?)?.toInt() ?? 0,
              'produk_terlaris': '-',
              'stok_menipis': (body['low_stock_products'] as num?)?.toInt() ?? 0,
              'total_produk': 0,
              'sales_trend': body['sales_trend'] ?? [],
            };
          } else if (body['status'] == 'success' && body['data'] is Map) {
            return Map<String, dynamic>.from(body['data']);
          } else if (body['data'] is Map) {
            return Map<String, dynamic>.from(body['data']);
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

    final now = DateTime.now();
    List<Map<String, dynamic>> trend = [];
    for (int i = 6; i >= 0; i--) {
      final dayDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      int dayTotal = 0;
      if (i == 0) {
        dayTotal = omzet;
      }
      trend.add({'date': dayDate.toIso8601String(), 'total': dayTotal});
    }

    final categories = [
      {
        'name': 'Electronics',
        'percentage': 45,
        'color': 0xFF6366F1,
        'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=200&auto=format&fit=crop&q=80',
      },
      {
        'name': 'Fashion',
        'percentage': 35,
        'color': 0xFF10B981,
        'image': 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=200&auto=format&fit=crop&q=80',
      },
      {
        'name': 'Beauty',
        'percentage': 20,
        'color': 0xFFF97316,
        'image': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&auto=format&fit=crop&q=80',
      },
    ];

    final displayRevenue = omzet > 0 ? omzet : 14012;
    final displayOrders = totalTrx > 0 ? totalTrx : 1015;

    return {
      'omzet': displayRevenue,
      'total_transaksi': displayOrders,
      'total_revenue': displayRevenue,
      'total_orders': displayOrders,
      'units_sold': 1158,
      'returning_customers': 86,
      'revenue_growth': '+6%',
      'revenue_growth_alt': '+16%',
      'orders_growth': '+9%',
      'produk_terlaris': produkTerlaris != '-' ? produkTerlaris : 'PUMA Magnify Nitro 3',
      'stok_menipis': stokMenipis,
      'total_produk': totalProduk,
      'sales_trend': trend,
      'top_categories': categories,
      'recent_activities': _fallbackTransactions,
      'top_products': _fallbackProducts.take(4).toList(),
    };
  }
}
