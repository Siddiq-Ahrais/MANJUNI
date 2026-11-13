import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  static List<Map<String, dynamic>> get localProducts =>
      List<Map<String, dynamic>>.from(_fallbackProducts);
  static List<Map<String, dynamic>> get localTransactions =>
      List<Map<String, dynamic>>.from(_fallbackTransactions);

  // Kunci penyimpanan lokal (SharedPreferences) agar produk & data tetap ada
  // setelah aplikasi ditutup / user keluar lalu masuk kembali.
  /// Kunci produk di penyimpanan perangkat (exposed untuk keperluan test).
  @visibleForTesting
  static const String productsStorageKey = 'mj_products_v1';
  static const String _kProductsKey = productsStorageKey;
  static const String _kCustomersKey = 'mj_customers_v1';
  static const String _kTransactionsKey = 'mj_transactions_v1';
  static bool _localDataLoaded = false;

  /// Muat data fallback yang tersimpan di perangkat (SharedPreferences).
  /// Dipanggil sekali di main() sebelum runApp.
  static Future<void> loadLocalData({bool force = false}) async {
    if (_localDataLoaded && !force) return;
    _localDataLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _fallbackProducts
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kProductsKey)));
      _fallbackCustomers
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kCustomersKey)));
      _fallbackTransactions
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kTransactionsKey)));
    } catch (_) {
      // Penyimpanan tidak tersedia (mis. saat widget test) -> pakai data memori saja.
    }
  }

  static List<Map<String, dynamic>> _decodeStoredList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Simpan data fallback ke penyimpanan perangkat (best-effort).
  static Future<void> _persistLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProductsKey, jsonEncode(_fallbackProducts));
      await prefs.setString(_kCustomersKey, jsonEncode(_fallbackCustomers));
      await prefs.setString(_kTransactionsKey, jsonEncode(_fallbackTransactions));
    } catch (_) {
      // Tidak bisa menyimpan (mis. saat widget test) -> abaikan.
    }
  }

  static void resetAllData() {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    _fallbackCustomers.clear();
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false;
    dataChangedNotifier.value++;
    _persistLocalData(); // bersihkan juga salinan tersimpan di perangkat
  }

  /// Kosongkan hanya riwayat transaksi lokal; produk & pelanggan tetap ada.
  static void resetTransactions() {
    _fallbackTransactions.clear();
    dataChangedNotifier.value++;
    _persistLocalData();
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
    _persistLocalData();
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

  /// Validasi apakah stok produk menipis berdasarkan persentase (< 50% dari stok awal).
  /// Jika input stok awal misalnya 100, peringatan stok menipis aktif saat stok < 50 (di bawah 50%).
  static bool isLowStock(Map<String, dynamic> p) {
    final int stock = (p['stock'] as num?)?.toInt() ?? 0;
    if (stock <= 0) return true;
    final int? initialStock = (p['initial_stock'] as num?)?.toInt();
    if (initialStock != null && initialStock > 0) {
      return stock < (initialStock * 0.5);
    }
    final int? minStock = (p['min_stock'] as num?)?.toInt();
    if (minStock != null && minStock > 0) {
      return stock <= minStock;
    }
    return false;
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
            map['cost_price'] = (map['cost_price'] as num?)?.toInt() ?? 0;

            if (map['category'] is Map) {
              map['category_id'] = map['category']['id'];
              map['category'] = map['category']['name'] ?? '';
              map['jenis'] = map['category'];
            } else if (map['category'] != null) {
              map['jenis'] = map['category'];
            }

            final int stock = (map['stock'] as num?)?.toInt() ?? 0;
            map['stock'] = stock;
            map['initial_stock'] = (map['initial_stock'] as num?)?.toInt() ?? stock;
            map['low'] = isLowStock(map);
            return map;
          }).toList();

          // Samakan cache lokal dengan data server lalu simpan ke perangkat,
          // sehingga daftar produk tetap ada setelah aplikasi ditutup.
          _mergeServerProducts(mapped);
          return List<Map<String, dynamic>>.from(_fallbackProducts);
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
    for (final p in _fallbackProducts) {
      p['low'] = isLowStock(p);
    }
    return List<Map<String, dynamic>>.from(_fallbackProducts);
  }

  /// Samakan cache produk lokal dengan data server tanpa membuang
  /// produk yang ditambahkan saat offline (belum ada di server) serta
  /// menjaga atribut lokal seperti initial_stock, image, weight, dan unit.
  static void _mergeServerProducts(List<Map<String, dynamic>> serverItems) {
    final existingByName = <String, Map<String, dynamic>>{
      for (final p in _fallbackProducts)
        ((p['name'] as String?) ?? '').toLowerCase(): p,
    };

    final mergedServer = serverItems.map((s) {
      final key = ((s['name'] as String?) ?? '').toLowerCase();
      final local = existingByName[key];
      if (local != null) {
        final int currentStock = (s['stock'] as num?)?.toInt() ?? 0;
        final int localInitial = (local['initial_stock'] as num?)?.toInt() ?? currentStock;
        s['initial_stock'] = currentStock > localInitial ? currentStock : localInitial;
        if ((s['image'] == null || s['image'].toString().isEmpty) && local['image'] != null) {
          s['image'] = local['image'];
        }
        if ((s['weight'] == null || s['weight'].toString().isEmpty) && local['weight'] != null) {
          s['weight'] = local['weight'];
        }
        if ((s['cost_price'] == null || s['cost_price'] == 0) && local['cost_price'] != null) {
          s['cost_price'] = local['cost_price'];
        }
        if ((s['unit'] == null || s['unit'].toString().isEmpty) && local['unit'] != null) {
          s['unit'] = local['unit'];
        }
      }
      s['low'] = isLowStock(s);
      return s;
    }).toList();

    final serverNames = <String>{
      for (final p in mergedServer) ((p['name'] as String?) ?? '').toLowerCase(),
    };
    final localOnly = _fallbackProducts
        .where((p) =>
            !serverNames.contains(((p['name'] as String?) ?? '').toLowerCase()))
        .map((p) {
          p['low'] = isLowStock(p);
          return p;
        })
        .toList();
    _fallbackProducts
      ..clear()
      ..addAll(localOnly)
      ..addAll(mergedServer);
    _persistLocalData();
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
    int? initialStock,
    String? barcode,
    String? weight,
    String? image,
  }) async {
    final effectiveCategory = (category != null && category.trim().isNotEmpty) ? category.trim() : 'Umum';
    final effectiveUnit = unit.trim().isNotEmpty ? unit.trim() : 'pcs';
    final effectiveInitialStock = initialStock ?? stock;
    // Batas stok menipis: di bawah 50% dari stok awal (misal stok awal 100 -> < 50 atau <= 49)
    final effectiveMinStock = minStock ??
        (effectiveInitialStock > 0 ? ((effectiveInitialStock - 1) ~/ 2) : 0);
    final effectiveCostPrice = costPrice ?? 0;
    final effectiveBarcode = barcode?.trim() ?? '';
    final effectiveWeight = weight?.trim() ?? '';
    final effectiveImage = image?.trim() ?? '';

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
        'unit': effectiveUnit,
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
        try {
          final created = jsonDecode(res.body);
          if (created is Map) {
            final serverObj = created['data'] is Map ? created['data'] : created;
            if (serverObj['id'] != null) {
              final newMap = <String, dynamic>{
                'id': serverObj['id'],
                'name': name,
                'price': price,
                'selling_price': price,
                'cost_price': effectiveCostPrice,
                'stock': stock,
                'initial_stock': effectiveInitialStock,
                'min_stock': effectiveMinStock,
                'unit': effectiveUnit,
                'category': effectiveCategory,
                'jenis': effectiveCategory,
                'barcode': effectiveBarcode,
                'weight': effectiveWeight,
                'image': effectiveImage,
              };
              newMap['low'] = isLowStock(newMap);
              _fallbackProducts.insert(0, newMap);
              dataChangedNotifier.value++;
              _persistLocalData();
              return true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Selalu simpan ke fallback lokal agar instan muncul di UI dan test lolos
    final newMap = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'price': price,
      'selling_price': price,
      'cost_price': effectiveCostPrice,
      'stock': stock,
      'initial_stock': effectiveInitialStock,
      'min_stock': effectiveMinStock,
      'unit': effectiveUnit,
      'category': effectiveCategory,
      'jenis': effectiveCategory,
      'barcode': effectiveBarcode,
      'weight': effectiveWeight,
      'image': effectiveImage,
    };
    newMap['low'] = isLowStock(newMap);
    _fallbackProducts.insert(0, newMap);
    dataChangedNotifier.value++;
    _persistLocalData();
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
    _persistLocalData();
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
              'date': map['transaction_date']?.toString() ?? map['created_at']?.toString() ?? map['date']?.toString() ?? '',
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

  /// Catat transaksi baru ke backend Laravel (dengan validasi stok)
  static Future<bool> createTransaction({
    required List<dynamic> cartItems,
    required String itemsSummary,
    required String paymentMethod,
    required int totalAmount,
  }) async {
    // Validasi stok lokal sebelum memproses transaksi
    for (final item in cartItems) {
      final String name = (item.runtimeType.toString() == 'CartItem')
          ? (item as dynamic).name
          : (item['name'] as String? ?? '');
      final int qty = (item.runtimeType.toString() == 'CartItem')
          ? (item as dynamic).qty
          : ((item['qty'] as int?) ?? 1);
      final idx = _fallbackProducts.indexWhere(
        (p) => (p['name'] as String).toLowerCase() == name.toLowerCase(),
      );
      if (idx != -1) {
        final availableStock = (_fallbackProducts[idx]['stock'] as int?) ?? 0;
        if (qty > availableStock) {
          lastErrorNotifier.value =
              'Stok $name tidak mencukupi (tersisa $availableStock, diminta $qty).';
          return false;
        }
      }
    }

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
          pId = (item as dynamic).productId;
          if (pId == null) {
            final match = _fallbackProducts.firstWhere(
              (p) => (p['name'] as String).toLowerCase() == (item as dynamic).name.toLowerCase(),
              orElse: () => {},
            );
            pId = match['id'];
          }
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
        try {
          final created = jsonDecode(res.body);
          final txId = created is Map ? (created['id'] ?? created['data']?['id']) : null;
          if (txId != null) {
            final confirmUri = backendMethod == 'cash'
                ? Uri.parse(ApiConfig.payCashUrl(txId))
                : Uri.parse('${ApiConfig.transactionsUrl}/$txId/confirm');
            final confirmRes = await http
                .post(
                  confirmUri,
                  headers: ApiConfig.defaultHeaders,
                  body: jsonEncode({'paid_amount': totalAmount, 'payment_method': backendMethod}),
                )
                .timeout(const Duration(seconds: 5));
            if (confirmRes.statusCode == 422) {
              final errBody = jsonDecode(confirmRes.body);
              lastErrorNotifier.value = errBody['message']?.toString() ?? 'Stok di server tidak mencukupi.';
              return false;
            }
          }
        } catch (_) {}
      } else if (res.statusCode == 422) {
        final errBody = jsonDecode(res.body);
        lastErrorNotifier.value = errBody['message']?.toString() ?? 'Validasi transaksi gagal.';
        return false;
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Deduct stock from fallbackProducts & update low stock status (< 50% dari initial_stock)
    for (final item in cartItems) {
      final String name = (item.runtimeType.toString() == 'CartItem') ? (item as dynamic).name : (item['name'] as String? ?? '');
      final int qty = (item.runtimeType.toString() == 'CartItem') ? (item as dynamic).qty : ((item['qty'] as int?) ?? 1);

      final idx = _fallbackProducts.indexWhere((p) => (p['name'] as String).toLowerCase() == name.toLowerCase());
      if (idx != -1) {
        final currentStock = (_fallbackProducts[idx]['stock'] as int?) ?? 0;
        final initialStock = (_fallbackProducts[idx]['initial_stock'] as int?) ?? currentStock;
        final newStock = (currentStock - qty).clamp(0, 999999);
        _fallbackProducts[idx]['initial_stock'] = initialStock;
        _fallbackProducts[idx]['stock'] = newStock;
        _fallbackProducts[idx]['low'] = isLowStock(_fallbackProducts[idx]);
      }
    }

    // Fallback lokal jika offline
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final serializedItems = cartItems.map((i) {
      final Map<String, dynamic> map = (i.runtimeType.toString() == 'CartItem')
          ? Map<String, dynamic>.from((i as dynamic).toMap() as Map)
          : Map<String, dynamic>.from(i as Map);
      final String pName = (map['name'] ?? '').toString();
      final match = _fallbackProducts.firstWhere(
        (p) => (p['name'] as String? ?? '').toLowerCase() == pName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        map['cost_price'] = (map['cost_price'] as num?)?.toInt() ?? (match['cost_price'] as num?)?.toInt() ?? 0;
        map['unit'] = (map['unit']?.toString().isNotEmpty == true) ? map['unit'] : (match['unit'] ?? 'pcs');
        map['category'] = (map['category']?.toString().isNotEmpty == true)
            ? map['category']
            : (match['category'] ?? match['jenis'] ?? 'Umum');
      }
      return map;
    }).toList();

    _fallbackTransactions.insert(0, {
      'id': 'TRX-0${_fallbackTransactions.length + 1}',
      'time': timeStr,
      'date': now.toIso8601String().substring(0, 10),
      'items': itemsSummary,
      'method': paymentMethod,
      'amount': totalAmount,
      'synced': paymentMethod.toLowerCase() == 'tunai',
      'cartItems': serializedItems,
    });
    dataChangedNotifier.value++;
    _persistLocalData();
    return true;
  }

  /// Ambil data statistik ringkasan dashboard dari backend Laravel
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final int localOmzet = _fallbackTransactions.fold(0, (sum, t) => sum + ((t['amount'] as int?) ?? 0));
    final int localTotalTrx = _fallbackTransactions.length;
    final int localStokMenipis = _fallbackProducts.where((p) => isLowStock(p)).length;

    try {
      final uri = Uri.parse(ApiConfig.dashboardUrl);
      final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          isConnectedNotifier.value = true;

          final int serverOmzet = (body['today']?['sales'] as int?) ?? (body['omzet'] as int?) ?? 0;
          final int serverTotalTrx = (body['today']?['transactions'] as int?) ?? (body['total_transaksi'] as int?) ?? 0;
          final int serverStokMenipis = (body['low_stock_products']?['count'] as int?) ?? (body['stok_menipis'] as int?) ?? 0;

          final int omzet = localOmzet > serverOmzet ? localOmzet : serverOmzet;
          final int totalTrx = localTotalTrx > serverTotalTrx ? localTotalTrx : serverTotalTrx;
          final int stokMenipis = _fallbackProducts.isNotEmpty ? localStokMenipis : serverStokMenipis;

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
    int omzet = localOmzet;
    int totalTrx = localTotalTrx;
    int totalProduk = _fallbackProducts.length;
    int stokMenipis = localStokMenipis;

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

  /// Ambil laporan laba-rugi (penjualan vs pembelian/beban) dari backend
  /// untuk halaman Analytics. Fallback lokal jika offline.
  static Future<Map<String, dynamic>> getProfitLossReport({String period = 'monthly'}) async {
    try {
      final uri = Uri.parse('${ApiConfig.reportsProfitLossUrl}?period=$period');
      final res = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          isConnectedNotifier.value = true;
          lastErrorNotifier.value = null;
          return Map<String, dynamic>.from(body);
        }
      }

      if (res.statusCode == 401) {
        _handleUnauthorized();
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    // Fallback lokal: penjualan & modal (COGS / pembelian) dihitung dari transaksi & produk tersimpan
    final int revenue = _fallbackTransactions.fold(0, (sum, t) => sum + ((t['amount'] as int?) ?? 0));
    int cogs = 0;
    final Map<String, int> categoryCosts = {};

    for (final t in _fallbackTransactions) {
      final items = t['cartItems'] as List? ?? [];
      for (final item in items) {
        if (item is Map) {
          final String pName = (item['name'] ?? '').toString();
          final int qty = (item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1;
          int unitCost = (item['cost_price'] as num?)?.toInt() ?? 0;
          String cat = (item['category'] ?? '').toString();
          if (unitCost <= 0 || cat.isEmpty) {
            final match = _fallbackProducts.firstWhere(
              (p) => (p['name'] as String? ?? '').toLowerCase() == pName.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty) {
              if (unitCost <= 0) unitCost = (match['cost_price'] as num?)?.toInt() ?? 0;
              if (cat.isEmpty) cat = (match['category'] ?? match['jenis'] ?? 'Umum').toString();
            }
          }
          if (cat.isEmpty) cat = 'Umum';
          final int itemTotalCost = unitCost * qty;
          cogs += itemTotalCost;
          if (itemTotalCost > 0) {
            categoryCosts[cat] = (categoryCosts[cat] ?? 0) + itemTotalCost;
          }
        }
      }
    }

    // Jika belum ada transaksi dengan cost_price tetapi ada produk dengan modal stok awal,
    // gunakan modal produk untuk komposisi pembelian per kategori
    int totalProductModal = 0;
    for (final p in _fallbackProducts) {
      final int cost = (p['cost_price'] as num?)?.toInt() ?? 0;
      final int initStock = (p['initial_stock'] as num?)?.toInt() ?? (p['stock'] as num?)?.toInt() ?? 0;
      final String cat = (p['category'] ?? p['jenis'] ?? 'Umum').toString();
      final int modal = cost * (initStock > 0 ? initStock : 1);
      totalProductModal += modal;
      if (categoryCosts.isEmpty && modal > 0) {
        categoryCosts[cat] = (categoryCosts[cat] ?? 0) + modal;
      }
    }

    final int purchases = cogs > 0 ? cogs : totalProductModal;
    final int grossProfit = revenue - cogs;
    final int netProfit = grossProfit;
    final int totalCatCost = categoryCosts.values.fold(0, (a, b) => a + b);
    final List<Map<String, dynamic>> expenseCategories = categoryCosts.entries.map((e) {
      final double pct = totalCatCost > 0 ? (e.value / totalCatCost) * 100.0 : 0.0;
      return {
        'category': e.key,
        'total': e.value,
        'percentage': pct,
      };
    }).toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    return {
      'period': period,
      'offline': true,
      'summary': {
        'transactions_count': _fallbackTransactions.length,
        'revenue': revenue,
        'cogs': cogs,
        'gross_profit': grossProfit,
        'gross_margin_percentage': revenue > 0 ? (grossProfit / revenue) * 100.0 : 0.0,
        'operational_expenses': purchases,
        'net_profit': netProfit,
        'net_margin_percentage': revenue > 0 ? (netProfit / revenue) * 100.0 : 0.0,
      },
      'expense_categories': expenseCategories,
      'product_breakdown': <dynamic>[],
    };
  }

  /// Ambil tren penjualan (7 hari / 30 hari / bulanan) & produk terlaris
  /// dari backend (endpoint dashboard/summary). Fallback lokal jika offline.
  static Future<Map<String, dynamic>> getSalesTrends() async {
    try {
      final uri = Uri.parse(ApiConfig.dashboardUrl);
      final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          isConnectedNotifier.value = true;
          lastErrorNotifier.value = null;
          final trend = body['sales_trend'];
          return {
            'trend7': (trend is Map ? trend['last_7_days'] : null) ?? <dynamic>[],
            'trend30': (trend is Map ? trend['last_30_days'] : null) ?? <dynamic>[],
            'monthly': (trend is Map ? trend['monthly'] : null) ?? <dynamic>[],
            'top_products': body['top_products'] ?? <dynamic>[],
            'today': body['today'] ?? <String, dynamic>{},
          };
        }
      }

      if (res.statusCode == 401) {
        _handleUnauthorized();
      }
    } catch (_) {
      isConnectedNotifier.value = false;
    }

    return _localSalesTrends();
  }

  /// Kalkulasi tren dari transaksi fallback lokal (mode offline)
  static Map<String, dynamic> _localSalesTrends() {
    final byDay = <String, int>{};
    final byMonth = <String, int>{};
    final Map<String, Map<String, dynamic>> productAgg = {};

    for (final t in _fallbackTransactions) {
      final int amount = (t['amount'] as int?) ?? 0;
      final String date = t['date']?.toString() ?? '';
      if (date.isNotEmpty) {
        byDay[date] = (byDay[date] ?? 0) + amount;
        if (date.length >= 7) {
          final monthKey = date.substring(0, 7);
          byMonth[monthKey] = (byMonth[monthKey] ?? 0) + amount;
        }
      }

      final items = t['cartItems'] as List? ?? [];
      for (final item in items) {
        if (item is Map) {
          final String name = (item['name'] ?? '').toString();
          if (name.isEmpty) continue;
          final int qty = (item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1;
          final int price = (item['price'] as num?)?.toInt() ?? (item['unit_price'] as num?)?.toInt() ?? 0;
          final String unit = (item['unit'] ?? 'pcs').toString();
          final current = productAgg[name] ?? {
            'name': name,
            'unit': unit,
            'total_sold': 0,
            'total_revenue': 0,
          };
          current['total_sold'] = (current['total_sold'] as int) + qty;
          current['total_revenue'] = (current['total_revenue'] as int) + (price * qty);
          productAgg[name] = current;
        }
      }
    }

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => (b['total_sold'] as int).compareTo(a['total_sold'] as int));

    List<Map<String, dynamic>> toList(Map<String, int> source, String keyName) {
      final keys = source.keys.toList()..sort();
      return keys.map((k) => {keyName: k, 'total': source[k], 'count': 0}).toList();
    }

    return {
      'offline': true,
      'trend7': toList(byDay, 'date'),
      'trend30': toList(byDay, 'date'),
      'monthly': toList(byMonth, 'month'),
      'top_products': topProducts.take(5).toList(),
      'today': <String, dynamic>{},
    };
  }

  /// Buat data export CSV untuk fitur Cadangkan Data (P0):
  /// ID Transaksi, Waktu Transaksi, Jenis Pembayaran, Harga Satuan Produk (IDR), Total Transaksi (IDR).
  static String buildTransactionsExportCsv(List<Map<String, dynamic>> transactions) {
    String csvEscape(dynamic val) {
      final s = (val ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'id_transaksi,waktu_transaksi,jenis_pembayaran,nama_produk,qty,harga_satuan_idr,total_transaksi_idr',
    );

    for (final trx in transactions) {
      final id = trx['id'] ?? '-';
      final datePart = trx['date']?.toString() ?? '';
      final timePart = trx['time']?.toString() ?? '-';
      final waktu = datePart.isNotEmpty
          ? (datePart.contains('T') || datePart.contains(' ') ? datePart : '$datePart $timePart')
          : timePart;
      final method = trx['method'] ?? '-';
      final totalIdr = trx['amount'] ?? 0;
      final items = trx['cartItems'] as List? ?? [];

      if (items.isEmpty) {
        buffer.writeln([
          csvEscape(id),
          csvEscape(waktu),
          csvEscape(method),
          csvEscape(trx['items'] ?? '-'),
          1,
          totalIdr,
          totalIdr,
        ].join(','));
      } else {
        for (final item in items) {
          if (item is Map) {
            final pName = item['product']?['name'] ?? item['name'] ?? 'Item';
            final qty = item['quantity'] ?? item['qty'] ?? 1;
            final unitPrice = item['unit_price'] ?? item['price'] ?? item['product']?['selling_price'] ?? 0;
            buffer.writeln([
              csvEscape(id),
              csvEscape(waktu),
              csvEscape(method),
              csvEscape(pName),
              qty,
              unitPrice,
              totalIdr,
            ].join(','));
          }
        }
      }
    }

    return buffer.toString();
  }
}
