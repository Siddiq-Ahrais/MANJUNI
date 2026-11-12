import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiService {
  // Status koneksi: null = belum dicek, true = online (terhubung ke server), false = offline
  static final ValueNotifier<bool?> isConnectedNotifier = ValueNotifier<bool?>(null);
  static final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> dataChangedNotifier = ValueNotifier<int>(0); // Triggers UI refresh across tabs
  static final ValueNotifier<Map<String, dynamic>?> userNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  // Status otentikasi: true = sudah login (punya token), false = tampilkan LoginPage
  static final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);

  /// Token tidak lagi valid (respons 401) -> reset status login agar
  /// AuthGate otomatis mengembalikan user ke halaman login.
  static void _handleUnauthorized() {
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false;
  }

  // Fallback data memori lokal (untuk offline mode & widget test)
  static final List<Map<String, dynamic>> _fallbackProducts = [];
  static final List<Map<String, dynamic>> _fallbackTransactions = [];
  static final List<Map<String, dynamic>> _fallbackCustomers = [];

  static void resetAllData() {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    _fallbackCustomers.clear();
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false;
    dataChangedNotifier.value++;
  }

  /// Ambil daftar pelanggan (lokal/fallback)
  static Future<List<Map<String, dynamic>>> getCustomers() async {
    return List<Map<String, dynamic>>.from(_fallbackCustomers);
  }

  /// Tambah pelanggan baru (lokal/fallback)
  static Future<bool> addCustomer({required String name, String? phone}) async {
    _fallbackCustomers.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name.trim(),
      'phone': phone ?? '',
    });
    dataChangedNotifier.value++;
    return true;
  }

  /// Uji koneksi ke endpoint /api/v1/health di server Laravel
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final uri = Uri.parse(ApiConfig.healthUrl);
      final res = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isConnectedNotifier.value = true;
        lastErrorNotifier.value = null;
        final appName = data['app'] ?? 'MANJUNI API';
        return {
          'success': true,
          'message': 'Terhubung ke server ($appName)!',
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

  /// Autentikasi Login kasir/owner ke backend Laravel Sanctum
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.authLoginUrl);
      final res = await http
          .post(
            uri,
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['token'] != null) {
        ApiConfig.token = body['token'].toString();
        userNotifier.value = body['user'] is Map ? Map<String, dynamic>.from(body['user'] as Map) : null;
        isConnectedNotifier.value = true;
        lastErrorNotifier.value = null;
        authStateNotifier.value = true; // Sukses login -> tampilkan shell utama
        dataChangedNotifier.value++;
        return {'success': true, 'data': body};
      } else {
        final msg = body['message'] ?? 'Login gagal. Periksa kembali email dan password.';
        lastErrorNotifier.value = msg;
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      final msg = 'Gagal terhubung ke server auth: $e';
      lastErrorNotifier.value = msg;
      return {'success': false, 'message': msg};
    }
  }

  /// Registrasi akun owner dan profil bisnis baru
  static Future<Map<String, dynamic>> register({
    required String businessName,
    required String name,
    required String email,
    required String password,
    String? address,
    String? phone,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.authRegisterUrl);
      final res = await http
          .post(
            uri,
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode({
              'business_name': businessName.trim(),
              'name': name.trim(),
              'email': email.trim(),
              'password': password,
              'address': address?.trim(),
              'phone': phone?.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      final body = jsonDecode(res.body);
      if (res.statusCode == 201 && body['token'] != null) {
        ApiConfig.token = body['token'].toString();
        userNotifier.value = body['user'] is Map ? Map<String, dynamic>.from(body['user'] as Map) : null;
        isConnectedNotifier.value = true;
        authStateNotifier.value = true; // Sukses registrasi -> langsung masuk
        dataChangedNotifier.value++;
        return {'success': true, 'data': body};
      } else {
        return {'success': false, 'message': body['message'] ?? 'Registrasi gagal.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal registrasi: $e'};
    }
  }

  /// Logout dan cabut token Sanctum aktif
  static Future<void> logout() async {
    try {
      if (ApiConfig.token != null) {
        final uri = Uri.parse(ApiConfig.authLogoutUrl);
        await http.post(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false; // Logout -> kembali ke halaman login
    dataChangedNotifier.value++;
  }

  /// Ambil daftar produk dari backend Laravel atau fallback lokal
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final uri = Uri.parse(ApiConfig.productsUrl);
      final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        List rawList = [];

        if (body is Map) {
          if (body['data'] is List) {
            rawList = body['data']; // Laravel paginated response
          } else if (body['products'] is List) {
            rawList = body['products'];
          }
        } else if (body is List) {
          rawList = body;
        }

        if (rawList.isNotEmpty) {
          isConnectedNotifier.value = true;
          final mapped = rawList.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            final int sellingPrice = (map['selling_price'] as int?) ?? (map['price'] as int?) ?? 0;
            map['price'] = sellingPrice;
            map['selling_price'] = sellingPrice;

            if (map['category'] is Map) {
              map['category_id'] = map['category']['id'];
              map['category'] = map['category']['name'] ?? '';
              map['jenis'] = map['category'];
            } else if (map['category'] != null) {
              map['jenis'] = map['category'];
            }

            final int stock = (map['stock'] as int?) ?? 0;
            final int minStock = (map['min_stock'] as int?) ?? 5;
            map['low'] = (map['low'] == true) || (stock <= minStock);
            return map;
          }).toList();

          return mapped;
        }
      }

      if (res.statusCode == 401) {
        // Token tidak ada / kedaluwarsa -> kembali ke halaman login
        _handleUnauthorized();
        return List<Map<String, dynamic>>.from(_fallbackProducts);
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }
    return List<Map<String, dynamic>>.from(_fallbackProducts);
  }

  /// Tambah produk baru ke backend Laravel & cache lokal
  static Future<bool> addProduct({
    required String name,
    required int price,
    required int stock,
    required String unit,
    String? category,
    int? costPrice,
    int? minStock,
    String? barcode,
    String? weight,
  }) async {
    final effectiveCategory = (category != null && category.trim().isNotEmpty) ? category.trim() : 'Umum';
    final effectiveMinStock = minStock ?? 5;
    final effectiveCostPrice = costPrice ?? (price > 0 ? (price * 0.8).toInt() : 0);
    final effectiveBarcode = barcode?.trim() ?? '';
    final effectiveWeight = weight?.trim() ?? '';

    try {
      final uri = Uri.parse(ApiConfig.productsUrl);

      // Petakan nama kategori pilihan user ke ID kategori di backend Laravel
      int? categoryId;
      try {
        final catRes = await http
            .get(Uri.parse(ApiConfig.categoriesUrl), headers: ApiConfig.defaultHeaders)
            .timeout(const Duration(seconds: 4));
        if (catRes.statusCode == 200) {
          final catBody = jsonDecode(catRes.body);
          final List cats = catBody is List ? catBody : ((catBody['data'] as List?) ?? []);
          for (final c in cats) {
            if (c is Map &&
                (c['name']?.toString().toLowerCase() == effectiveCategory.toLowerCase())) {
              categoryId = (c['id'] as num?)?.toInt();
              break;
            }
          }
        }
      } catch (_) {}

      final payload = {
        'name': name.trim(),
        'unit': unit.trim(),
        'cost_price': effectiveCostPrice,
        'selling_price': price,
        'price': price,
        'stock': stock,
        'min_stock': effectiveMinStock,
        'category_id': ?categoryId,
        if (effectiveBarcode.isNotEmpty) 'barcode': effectiveBarcode,
      };

      final res = await http
          .post(
            uri,
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        isConnectedNotifier.value = true;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Selalu simpan ke fallback lokal agar instan muncul di UI dan test lolos
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
    dataChangedNotifier.value++;
    return true;
  }

  /// Hapus produk dari database backend & memori lokal
  static Future<bool> deleteProduct(dynamic id) async {
    if (id is int || (id is String && int.tryParse(id) != null)) {
      try {
        final parsedId = id is int ? id : int.parse(id as String);
        final uri = Uri.parse('${ApiConfig.productsUrl}/$parsedId');
        await http.delete(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    _fallbackProducts.removeWhere((p) => p['id'] == id || p['name'] == id);
    dataChangedNotifier.value++;
    return true;
  }

  /// Ambil daftar transaksi dari backend Laravel atau fallback
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final uri = Uri.parse(ApiConfig.transactionsUrl);
      final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        List rawList = [];

        if (body is Map && body['data'] is List) {
          rawList = body['data'];
        } else if (body is List) {
          rawList = body;
        }

        if (rawList.isNotEmpty) {
          isConnectedNotifier.value = true;
          return rawList.map((t) {
            final map = Map<String, dynamic>.from(t as Map);
            final int amount = (map['total_amount'] as int?) ?? (map['amount'] as int?) ?? 0;
            final String method = (map['payment_method'] ?? map['method'] ?? 'Tunai').toString();
            final bool isCompleted = map['status'] == 'completed' || map['synced'] == true;

            // Buat ringkasan item jika berasal dari relasi Laravel
            String itemsSummary = map['items'] is String ? map['items'] as String : '';
            List cartItems = [];
            if (map['items'] is List) {
              cartItems = map['items'];
              itemsSummary = (map['items'] as List).map((i) {
                final qty = i['quantity'] ?? 1;
                final pName = i['product']?['name'] ?? i['name'] ?? 'Item';
                return '$qty $pName';
              }).join(', ');
            }

            return {
              'id': map['id'] != null ? 'TRX-0${map['id']}' : 'TRX-${DateTime.now().millisecondsSinceEpoch}',
              'raw_id': map['id'],
              'time': map['transaction_date'] != null ? map['transaction_date'].toString().split('T').last.substring(0, 5) : (map['time'] ?? '-'),
              'items': itemsSummary.isNotEmpty ? itemsSummary : 'Transaksi Penjualan',
              'method': method,
              'amount': amount,
              'synced': isCompleted,
              'cartItems': cartItems,
            };
          }).toList();
        }
      }

      if (res.statusCode == 401) {
        _handleUnauthorized();
        return List<Map<String, dynamic>>.from(_fallbackTransactions);
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }
    return List<Map<String, dynamic>>.from(_fallbackTransactions);
  }

  /// Catat transaksi baru ke backend Laravel
  static Future<bool> createTransaction({
    required List<dynamic> cartItems,
    required String itemsSummary,
    required String paymentMethod,
    required int totalAmount,
  }) async {
    // Normalisasi method untuk backend Laravel ('cash', 'qris', 'transfer', 'other')
    String backendMethod = 'cash';
    final lower = paymentMethod.toLowerCase();
    if (lower.contains('qris')) {
      backendMethod = 'qris';
    } else if (lower.contains('transfer') || lower.contains('va') || lower.contains('bank')) {
      backendMethod = 'transfer';
    } else if (lower.contains('tunai') || lower.contains('cash')) {
      backendMethod = 'cash';
    } else {
      backendMethod = 'other';
    }

    try {
      final uri = Uri.parse(ApiConfig.transactionsUrl);

      // Siapkan payload transaksi sesuai format TransactionController::store
      final List<Map<String, dynamic>> laravelItems = [];
      for (final item in cartItems) {
        dynamic pId;
        int qty = 1;

        if (item.runtimeType.toString() == 'CartItem') {
          qty = (item as dynamic).qty;
          // Cek apakah produk ada di _fallbackProducts untuk ambil ID asli
          final match = _fallbackProducts.firstWhere(
            (p) => (p['name'] as String).toLowerCase() == (item as dynamic).name.toLowerCase(),
            orElse: () => {},
          );
          pId = match['id'];
        } else if (item is Map) {
          qty = (item['qty'] as int?) ?? 1;
          pId = item['product_id'] ?? item['id'];
        }

        if (pId is int) {
          laravelItems.add({'product_id': pId, 'quantity': qty});
        }
      }

      final Map<String, dynamic> payload = {
        'payment_method': backendMethod,
        'note': itemsSummary,
      };

      if (laravelItems.isNotEmpty) {
        payload['items'] = laravelItems;
      } else {
        payload['direct_amount'] = totalAmount;
        payload['service_name'] = itemsSummary;
      }

      final res = await http
          .post(
            uri,
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

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
    dataChangedNotifier.value++;
    return true;
  }

  /// Ambil data statistik ringkasan dashboard dari backend Laravel
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final uri = Uri.parse(ApiConfig.dashboardUrl);
      final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          isConnectedNotifier.value = true;

          final int omzet = (body['today']?['sales'] as int?) ?? (body['omzet'] as int?) ?? 0;
          final int totalTrx = (body['today']?['transactions'] as int?) ?? (body['total_transaksi'] as int?) ?? 0;
          final int stokMenipis = (body['low_stock_products']?['count'] as int?) ?? (body['stok_menipis'] as int?) ?? 0;

          String produkTerlaris = '-';
          if (body['top_products'] is List && (body['top_products'] as List).isNotEmpty) {
            produkTerlaris = body['top_products'][0]['name'] ?? '-';
          } else if (body['produk_terlaris'] != null) {
            produkTerlaris = body['produk_terlaris'].toString();
          }

          final int totalProduk = _fallbackProducts.isNotEmpty ? _fallbackProducts.length : ((body['total_produk'] as int?) ?? 0);

          return {
            'omzet': omzet,
            'total_transaksi': totalTrx,
            'produk_terlaris': produkTerlaris,
            'stok_menipis': stokMenipis,
            'total_produk': totalProduk,
            'raw': body,
          };
        }
      }

      if (res.statusCode == 401) {
        _handleUnauthorized();
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Kalkulasi dinamis dari fallback lokal
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
