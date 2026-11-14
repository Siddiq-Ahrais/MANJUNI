import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'cart_service.dart';

class ApiService {
  // Status koneksi: null = belum dicek, true = online (terhubung ke server), false = offline
  static final ValueNotifier<bool?> isConnectedNotifier = ValueNotifier<bool?>(false);
  static final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> dataChangedNotifier = ValueNotifier<int>(0); // Triggers UI refresh across tabs
  static final ValueNotifier<Map<String, dynamic>?> userNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  // Status otentikasi / kunci aplikasi:
  // true = aplikasi terbuka (default saat tidak ada PIN keamanan),
  // false = terkunci dan menampilkan layar PIN Keamanan (LoginPage)
  static final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(true);
  // Mode 100% Offline: true secara bawaan agar APK langsung berjalan di perangkat tanpa butuh server
  static final ValueNotifier<bool> offlineModeNotifier = ValueNotifier<bool>(true);

  /// Token tidak lagi valid (respons 401) -> jika sedang mode online murni dan bukan token lokal,
  /// baru kembali ke halaman login. Saat offline mode, sesi lokal tetap dipertahankan.
  static void _handleUnauthorized() {
    if (offlineModeNotifier.value) return;
    if (ApiConfig.token != null && ApiConfig.token!.startsWith('offline_token_')) {
      return;
    }
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false;
  }

  // Fallback data memori lokal (untuk offline mode & widget test)
  static final List<Map<String, dynamic>> _fallbackProducts = [];
  static final List<Map<String, dynamic>> _fallbackTransactions = [];
  static final List<Map<String, dynamic>> _fallbackCustomers = [];
  static final List<Map<String, dynamic>> _localUsers = [];
  static final Set<String> _deletedProductKeys = <String>{};

  static List<Map<String, dynamic>> get localProducts =>
      List<Map<String, dynamic>>.from(_fallbackProducts);
  static List<Map<String, dynamic>> get localTransactions =>
      List<Map<String, dynamic>>.from(_fallbackTransactions);

  // Kunci penyimpanan lokal (SharedPreferences) agar produk & data tetap ada
  // setelah aplikasi ditutup / user keluar lalu masuk kembali.
  // Menggunakan kunci _v2 yang bersih agar data lama/dummy terhapus dan
  // aplikasi dimulai benar-benar kosong seperti pengguna pertama kali.
  /// Kunci produk di penyimpanan perangkat (exposed untuk keperluan test).
  @visibleForTesting
  static const String productsStorageKey = 'mj_products_v2';
  static const String _kProductsKey = productsStorageKey;
  static const String _kCustomersKey = 'mj_customers_v2';
  static const String _kTransactionsKey = 'mj_transactions_v2';
  static const String _kTransactionsResetMaxIdKey = 'mj_transactions_reset_max_id_v2';
  static const String _kTransactionsResetAtKey = 'mj_transactions_reset_at_v2';
  static const String _kAuthTokenKey = 'mj_auth_token_v2';
  static const String _kAuthUserKey = 'mj_auth_user_v2';
  static const String _kUsersKey = 'mj_users_v2';
  static const String _kDeletedProductsKey = 'mj_deleted_products_v2';
  static const String _kOfflineModeKey = 'mj_offline_mode_v2';
  static const String _kSecurityPinKey = 'mj_security_pin_v2';
  static const String _kSecurityName1Key = 'mj_security_name_1_v2';
  static const String _kSecurityName2Key = 'mj_security_name_2_v2';
  static String _securityPin = '';
  static String _securityName1 = '';
  static String _securityName2 = '';
  static final RegExp alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');

  static bool get hasSecurityPin => _securityPin.isNotEmpty;
  static String get securityPin => _securityPin;
  static String get securityName1 => _securityName1;
  static String get securityName2 => _securityName2;

  static int _transactionsResetMaxId = 0;
  static int _lastFetchedMaxServerTxId = 0;
  static DateTime? _transactionsResetAt;
  static bool _localDataLoaded = false;

  /// Simpan pengaturan PIN Keamanan dan 2 Nama Keamanan (hanya huruf & angka).
  static Future<Map<String, dynamic>> setSecurityPin({
    required String pin,
    required String confirmPin,
    required String securityName1,
    required String securityName2,
  }) async {
    final cleanPin = pin.trim();
    final cleanConfirm = confirmPin.trim();
    final cleanName1 = securityName1.trim();
    final cleanName2 = securityName2.trim();

    if (cleanPin.isEmpty) {
      return {'success': false, 'message': 'PIN wajib diisi!'};
    }
    if (cleanPin != cleanConfirm) {
      return {
        'success': false,
        'message': 'PIN dan Konfirmasi PIN harus sama!',
      };
    }
    if (cleanName1.isEmpty || cleanName2.isEmpty) {
      return {
        'success': false,
        'message': 'Nama keamanan 1 dan Nama keamanan 2 wajib diisi!',
      };
    }
    if (!alphanumericRegex.hasMatch(cleanName1) ||
        !alphanumericRegex.hasMatch(cleanName2)) {
      return {
        'success': false,
        'message': 'Nama keamanan hanya boleh berisi huruf dan angka!',
      };
    }

    _securityPin = cleanPin;
    _securityName1 = cleanName1;
    _securityName2 = cleanName2;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'message': 'PIN keamanan dan 2 nama keamanan berhasil disimpan!',
    };
  }

  /// Hapus / nonaktifkan PIN keamanan perangkat.
  static Future<void> clearSecurityPin() async {
    _securityPin = '';
    _securityName1 = '';
    _securityName2 = '';
    authStateNotifier.value = true;
    dataChangedNotifier.value++;
    await _persistLocalData();
  }

  /// Verifikasi PIN keamanan untuk membuka kunci aplikasi.
  static bool verifySecurityPin(String inputPin) {
    if (_securityPin.isEmpty || _securityPin == inputPin.trim()) {
      authStateNotifier.value = true;
      return true;
    }
    return false;
  }

  /// Verifikasi kesesuaian 2 nama keamanan (Nama Keamanan 1 & Nama Keamanan 2).
  static bool verifySecurityNames({
    required String name1,
    required String name2,
  }) {
    final n1 = name1.trim().toLowerCase();
    final n2 = name2.trim().toLowerCase();
    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == _securityName1.trim().toLowerCase() &&
        n2 == _securityName2.trim().toLowerCase();
  }

  /// Ganti PIN keamanan dari dalam aplikasi (meminta PIN lama + 2 Nama Keamanan sebagai autentikasi keamanan).
  static Future<Map<String, dynamic>> changeSecurityPin({
    required String oldPin,
    required String securityName1,
    required String securityName2,
    required String newPin,
    required String confirmNewPin,
  }) async {
    final cleanOld = oldPin.trim();
    final cleanNew = newPin.trim();
    final cleanConfirm = confirmNewPin.trim();

    if (_securityPin.isEmpty) {
      return {
        'success': false,
        'message': 'PIN belum diatur. Gunakan menu Atur PIN Keamanan.',
      };
    }
    if (cleanOld.isEmpty || cleanOld != _securityPin) {
      return {
        'success': false,
        'message': 'PIN lama yang dimasukkan tidak sesuai!',
      };
    }
    if (!verifySecurityNames(name1: securityName1, name2: securityName2)) {
      return {
        'success': false,
        'message': 'Nama Keamanan 1 atau Nama Keamanan 2 tidak sesuai!',
      };
    }
    if (cleanNew.isEmpty) {
      return {'success': false, 'message': 'PIN baru wajib diisi!'};
    }
    if (cleanNew != cleanConfirm) {
      return {
        'success': false,
        'message': 'PIN baru dan Konfirmasi PIN baru harus sama!',
      };
    }

    _securityPin = cleanNew;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'message': 'PIN keamanan berhasil diganti!',
    };
  }

  /// Nonaktifkan PIN keamanan dari dalam aplikasi (wajib verifikasi PIN lama + 2 Nama Keamanan).
  static Future<Map<String, dynamic>> disableSecurityPinWithAuth({
    required String oldPin,
    required String securityName1,
    required String securityName2,
  }) async {
    if (oldPin.trim().isEmpty || oldPin.trim() != _securityPin) {
      return {
        'success': false,
        'message': 'PIN lama yang dimasukkan tidak sesuai!',
      };
    }
    if (!verifySecurityNames(name1: securityName1, name2: securityName2)) {
      return {
        'success': false,
        'message': 'Nama Keamanan 1 atau Nama Keamanan 2 tidak sesuai!',
      };
    }
    await clearSecurityPin();
    return {
      'success': true,
      'message': 'PIN keamanan berhasil dinonaktifkan!',
    };
  }

  /// Verifikasi 1 karakter terakhir dari masing-masing Nama Keamanan saat ini
  /// (misal Nama 1 "indah" -> "h", Nama 2 "laut" -> "t").
  static bool verifySecurityNamesLastChar({
    required String lastChar1,
    required String lastChar2,
  }) {
    final c1 = lastChar1.trim().toLowerCase();
    final c2 = lastChar2.trim().toLowerCase();
    final stored1 = _securityName1.trim().toLowerCase();
    final stored2 = _securityName2.trim().toLowerCase();
    if (c1.length != 1 || c2.length != 1 || stored1.isEmpty || stored2.isEmpty) {
      return false;
    }
    final expectedLast1 = stored1.substring(stored1.length - 1);
    final expectedLast2 = stored2.substring(stored2.length - 1);
    return c1 == expectedLast1 && c2 == expectedLast2;
  }

  /// Ganti kedua Nama Keamanan secara serentak dengan syarat:
  /// 1. Mengetahui PIN saat ini (`currentPin`)
  /// 2. Mengetahui 1 karakter terakhir dari kedua Nama Keamanan saat ini (`lastCharName1` & `lastCharName2`)
  /// 3. Mengisi kedua Nama Keamanan baru secara serentak (hanya huruf & angka)
  static Future<Map<String, dynamic>> changeSecurityNames({
    required String currentPin,
    required String lastCharName1,
    required String lastCharName2,
    required String newSecurityName1,
    required String newSecurityName2,
  }) async {
    final cleanPin = currentPin.trim();
    final cleanLast1 = lastCharName1.trim();
    final cleanLast2 = lastCharName2.trim();
    final cleanName1 = newSecurityName1.trim();
    final cleanName2 = newSecurityName2.trim();

    if (_securityPin.isEmpty || _securityName1.isEmpty || _securityName2.isEmpty) {
      return {
        'success': false,
        'message': 'PIN belum diatur. Atur PIN Keamanan terlebih dahulu!',
      };
    }
    if (cleanPin.isEmpty || cleanPin != _securityPin) {
      return {
        'success': false,
        'message': 'PIN saat ini yang dimasukkan tidak sesuai!',
      };
    }
    if (cleanLast1.length != 1 || cleanLast2.length != 1) {
      return {
        'success': false,
        'message':
            'Masukkan tepat 1 karakter terakhir dari Nama Keamanan 1 dan Nama Keamanan 2 saat ini!',
      };
    }
    if (!verifySecurityNamesLastChar(lastChar1: cleanLast1, lastChar2: cleanLast2)) {
      return {
        'success': false,
        'message':
            '1 karakter terakhir dari Nama Keamanan 1 atau Nama Keamanan 2 saat ini tidak sesuai!',
      };
    }
    if (cleanName1.isEmpty || cleanName2.isEmpty) {
      return {
        'success': false,
        'message':
            'Kedua Nama Keamanan (Nama Keamanan 1 & Nama Keamanan 2) wajib diisi secara serentak!',
      };
    }
    if (!alphanumericRegex.hasMatch(cleanName1) ||
        !alphanumericRegex.hasMatch(cleanName2)) {
      return {
        'success': false,
        'message': 'Nama keamanan hanya boleh berisi huruf dan angka!',
      };
    }

    _securityName1 = cleanName1;
    _securityName2 = cleanName2;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'message': 'Kedua Nama Keamanan berhasil diganti secara serentak!',
    };
  }

  /// Buka aplikasi melalui opsi Lupa Password / Lupa PIN dengan memasukkan 2 Nama Keamanan
  /// (PIN lama tidak dapat di-recovery; pengguna dapat langsung membuka aplikasi atau sekaligus mengatur PIN baru).
  static Future<Map<String, dynamic>> unlockWithSecurityNames({
    required String name1,
    required String name2,
    String? newPin,
    String? confirmPin,
  }) async {
    if (!verifySecurityNames(name1: name1, name2: name2)) {
      return {
        'success': false,
        'message': 'Nama Keamanan 1 atau Nama Keamanan 2 tidak sesuai!',
      };
    }
    final cleanNew = (newPin ?? '').trim();
    final cleanConfirm = (confirmPin ?? '').trim();
    if (cleanNew.isNotEmpty || cleanConfirm.isNotEmpty) {
      if (cleanNew.isEmpty) {
        return {'success': false, 'message': 'PIN baru wajib diisi!'};
      }
      if (cleanNew != cleanConfirm) {
        return {
          'success': false,
          'message': 'PIN baru dan Konfirmasi PIN baru harus sama!',
        };
      }
      _securityPin = cleanNew;
      await _persistLocalData();
    }
    authStateNotifier.value = true;
    dataChangedNotifier.value++;
    return {
      'success': true,
      'message': 'Verifikasi Nama Keamanan berhasil! Aplikasi dibuka.',
    };
  }

  /// Reset PIN baru menggunakan verifikasi 2 Nama Keamanan.
  static Future<Map<String, dynamic>> resetPinWithSecurityNames({
    required String name1,
    required String name2,
    required String newPin,
    required String confirmPin,
  }) async {
    return unlockWithSecurityNames(
      name1: name1,
      name2: name2,
      newPin: newPin,
      confirmPin: confirmPin,
    );
  }

  /// Mode aplikasi dikunci 100% offline di perangkat.
  static Future<void> setOfflineMode(bool isOffline) async {
    offlineModeNotifier.value = true;
    isConnectedNotifier.value = false;
    lastErrorNotifier.value = null;
    dataChangedNotifier.value++;
    await _persistLocalData();
  }

  /// Sinkronisasi / penyimpanan eksplisit data lokal di perangkat.
  static Future<Map<String, dynamic>> syncLocalData() async {
    await _persistLocalData();
    dataChangedNotifier.value++;
    return {
      'success': true,
      'offline': true,
      'products': _fallbackProducts.length,
      'transactions': _fallbackTransactions.length,
      'message':
          'Tersimpan di perangkat (${_fallbackProducts.length} produk, ${_fallbackTransactions.length} transaksi).',
    };
  }

  /// Muat data fallback yang tersimpan di perangkat (SharedPreferences).
  /// Dipanggil sekali di main() sebelum runApp.
  static Future<void> loadLocalData({bool force = false}) async {
    if (_localDataLoaded && !force) return;
    _localDataLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bersihkan kunci versi lama (_v1) agar perangkat bersih dari sisa data dummy/lama
      await prefs.remove('mj_products_v1');
      await prefs.remove('mj_customers_v1');
      await prefs.remove('mj_transactions_v1');
      await prefs.remove('mj_transactions_reset_max_id_v1');
      await prefs.remove('mj_transactions_reset_at_v1');
      await prefs.remove('mj_deleted_products_v1');

      _fallbackProducts
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kProductsKey)));
      _fallbackCustomers
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kCustomersKey)));
      _fallbackTransactions
        ..clear()
        ..addAll(
          _decodeStoredList(prefs.getString(_kTransactionsKey)).map((t) {
            final copy = Map<String, dynamic>.from(t);
            copy['synced'] = true;
            return copy;
          }),
        );
      _localUsers
        ..clear()
        ..addAll(_decodeStoredList(prefs.getString(_kUsersKey)));
      _deletedProductKeys
        ..clear()
        ..addAll(prefs.getStringList(_kDeletedProductsKey) ?? const <String>[]);
      _transactionsResetMaxId = prefs.getInt(_kTransactionsResetMaxIdKey) ?? 0;
      final resetAtRaw = prefs.getString(_kTransactionsResetAtKey);
      _transactionsResetAt =
          resetAtRaw != null ? DateTime.tryParse(resetAtRaw)?.toUtc() : null;
      offlineModeNotifier.value = true;
      _securityPin = (prefs.getString(_kSecurityPinKey) ?? '').trim();
      _securityName1 = (prefs.getString(_kSecurityName1Key) ?? '').trim();
      _securityName2 = (prefs.getString(_kSecurityName2Key) ?? '').trim();

      final savedUserRaw = prefs.getString(_kAuthUserKey);
      if (savedUserRaw != null && savedUserRaw.isNotEmpty) {
        try {
          final decodedUser = jsonDecode(savedUserRaw);
          if (decodedUser is Map) {
            userNotifier.value = Map<String, dynamic>.from(decodedUser);
          }
        } catch (_) {}
      }

      final savedToken = prefs.getString(_kAuthTokenKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        ApiConfig.token = savedToken;
      }

      // Jika user mengatur PIN keamanan, kunci aplikasi saat pertama dibuka;
      // jika tidak ada PIN keamanan, langsung masuk ke aplikasi (tanpa login password).
      authStateNotifier.value = _securityPin.isEmpty;

      await CartService.loadLocalCart();
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
      await prefs.setString(_kUsersKey, jsonEncode(_localUsers));
      await prefs.setStringList(_kDeletedProductsKey, _deletedProductKeys.toList());
      await prefs.setBool(_kOfflineModeKey, offlineModeNotifier.value);
      await prefs.setString(_kSecurityPinKey, _securityPin);
      await prefs.setString(_kSecurityName1Key, _securityName1);
      await prefs.setString(_kSecurityName2Key, _securityName2);
      await prefs.setInt(_kTransactionsResetMaxIdKey, _transactionsResetMaxId);
      if (_transactionsResetAt != null) {
        await prefs.setString(
          _kTransactionsResetAtKey,
          _transactionsResetAt!.toIso8601String(),
        );
      } else {
        await prefs.remove(_kTransactionsResetAtKey);
      }
      if (ApiConfig.token != null && ApiConfig.token!.isNotEmpty) {
        await prefs.setString(_kAuthTokenKey, ApiConfig.token!);
      } else {
        await prefs.remove(_kAuthTokenKey);
      }
      if (userNotifier.value != null) {
        await prefs.setString(_kAuthUserKey, jsonEncode(userNotifier.value));
      } else {
        await prefs.remove(_kAuthUserKey);
      }
    } catch (_) {
      // Tidak bisa menyimpan (mis. saat widget test) -> abaikan.
    }
  }

  static void resetAllData() {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    _fallbackCustomers.clear();
    _localUsers.clear();
    _deletedProductKeys.clear();
    _transactionsResetMaxId = 0;
    _lastFetchedMaxServerTxId = 0;
    _transactionsResetAt = null;
    _securityPin = '';
    _securityName1 = '';
    _securityName2 = '';
    offlineModeNotifier.value = true;
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = true;
    CartService.clear();
    dataChangedNotifier.value++;
    _persistLocalData(); // bersihkan juga salinan tersimpan di perangkat
  }

  /// Kosongkan seluruh data aplikasi (produk, transaksi, pelanggan, keranjang, identitas toko)
  /// sehingga aplikasi kembali benar-benar kosong seperti pengguna pertama kali.
  static Future<void> clearAllAppData({bool keepSecurityPin = false}) async {
    _fallbackProducts.clear();
    _fallbackTransactions.clear();
    _fallbackCustomers.clear();
    _localUsers.clear();
    _deletedProductKeys.clear();
    _transactionsResetMaxId = 0;
    _lastFetchedMaxServerTxId = 0;
    _transactionsResetAt = null;
    if (!keepSecurityPin) {
      _securityPin = '';
      _securityName1 = '';
      _securityName2 = '';
    }
    offlineModeNotifier.value = true;
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = true;
    CartService.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('store_name');
      await prefs.remove('store_category');
      await prefs.remove('mj_products_v1');
      await prefs.remove('mj_customers_v1');
      await prefs.remove('mj_transactions_v1');
      await prefs.remove('mj_cart_v1');
    } catch (_) {}
    await _persistLocalData();
    dataChangedNotifier.value++;
  }

  /// Kosongkan riwayat transaksi lokal dan di backend server (bila terhubung); produk & pelanggan tetap ada.
  static Future<void> resetTransactions() async {
    int maxKnownId = _lastFetchedMaxServerTxId;
    for (final t in _fallbackTransactions) {
      final rid = (t['raw_id'] as num?)?.toInt() ?? 0;
      if (rid > maxKnownId) maxKnownId = rid;
    }
    if (maxKnownId > _transactionsResetMaxId) {
      _transactionsResetMaxId = maxKnownId;
    }
    _transactionsResetAt = DateTime.now().toUtc();
    _fallbackTransactions.clear();

    if (!offlineModeNotifier.value &&
        ApiConfig.token != null &&
        ApiConfig.token!.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('${ApiConfig.transactionsUrl}/reset'),
              headers: ApiConfig.defaultHeaders,
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          // Server berhasil menghapus semua transaksi di DB; reset batas filter lokal
          // agar transaksi baru (atau hasil seed ulang) dengan ID kecil tidak ikut terfilter.
          _transactionsResetMaxId = 0;
          _lastFetchedMaxServerTxId = 0;
          _transactionsResetAt = null;
        }
      } catch (_) {}
    }

    dataChangedNotifier.value++;
    await _persistLocalData();
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

  /// Uji koneksi ke endpoint /api/v1/health di server Laravel (atau konfirmasi mode offline)
  static Future<Map<String, dynamic>> testConnection() async {
    if (offlineModeNotifier.value) {
      isConnectedNotifier.value = false;
      lastErrorNotifier.value = null;
      await _persistLocalData();
      return {
        'success': true,
        'offline': true,
        'message':
            'Mode Offline Aktif \u2022 Semua data tersimpan di perangkat (${_fallbackProducts.length} produk, ${_fallbackTransactions.length} transaksi).',
      };
    }

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
      final msg = 'Server tidak terjangkau \u2022 Beralih otomatis ke penyimpanan perangkat lokal.';
      lastErrorNotifier.value = msg;
      return {'success': false, 'offline': true, 'message': msg};
    }
  }

  static Map<String, dynamic> _buildOfflineUser({
    required String email,
    String? name,
    String? businessName,
  }) {
    final lower = email.trim().toLowerCase();
    String role = 'owner';
    String resolvedName = name?.trim() ?? '';
    if (lower.contains('kasir') || lower.contains('cashier')) {
      role = 'cashier';
      if (resolvedName.isEmpty) resolvedName = 'Kasir Toko';
    } else if (lower.contains('partner') || lower.contains('mitra')) {
      role = 'partner';
      if (resolvedName.isEmpty) resolvedName = 'Partner Usaha';
    } else {
      if (resolvedName.isEmpty) {
        final prefix = lower.contains('@') ? lower.split('@').first : lower;
        resolvedName = prefix.isNotEmpty
            ? '${prefix[0].toUpperCase()}${prefix.substring(1)}'
            : 'Owner Toko';
      }
    }
    return {
      'id': DateTime.now().millisecondsSinceEpoch,
      'name': resolvedName,
      'email': lower.isNotEmpty ? lower : 'owner@manjuni.local',
      'role': role,
      if (businessName != null && businessName.trim().isNotEmpty)
        'business_name': businessName.trim(),
    };
  }

  /// Masuk langsung ke Mode Offline tanpa perlu koneksi server (1-tap untuk juri/pengguna).
  static Future<Map<String, dynamic>> loginOfflineGuest({
    String? storeName,
    String? ownerName,
  }) async {
    offlineModeNotifier.value = true;
    isConnectedNotifier.value = false;
    lastErrorNotifier.value = null;

    if (storeName != null && storeName.trim().isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('store_name', storeName.trim());
      } catch (_) {}
    }

    final user = _buildOfflineUser(
      email: 'owner@manjuni.com',
      name: ownerName ?? 'Owner Toko (Offline)',
      businessName: storeName,
    );
    ApiConfig.token = 'offline_token_${DateTime.now().millisecondsSinceEpoch}';
    userNotifier.value = user;
    authStateNotifier.value = true;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'offline': true,
      'data': {'token': ApiConfig.token, 'user': user},
    };
  }

  /// Autentikasi Login kasir/owner (100% berjalan offline di perangkat maupun ke server bila aktif)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Email dan password wajib diisi!'};
    }

    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse(ApiConfig.authLoginUrl);
        final res = await http
            .post(
              uri,
              headers: ApiConfig.defaultHeaders,
              body: jsonEncode({
                'email': trimmedEmail,
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 6));

        final body = jsonDecode(res.body);
        if (res.statusCode == 200 && body['token'] != null) {
          ApiConfig.token = body['token'].toString();
          userNotifier.value = body['user'] is Map
              ? Map<String, dynamic>.from(body['user'] as Map)
              : null;
          isConnectedNotifier.value = true;
          lastErrorNotifier.value = null;
          authStateNotifier.value = true;
          dataChangedNotifier.value++;
          await _persistLocalData();
          return {'success': true, 'data': body};
        } else if (res.statusCode == 401 || res.statusCode == 422) {
          final msg = body['message'] ?? 'Login gagal. Periksa kembali email dan password.';
          lastErrorNotifier.value = msg;
          return {'success': false, 'message': msg};
        }
      } catch (_) {
        // Server tidak terjangkau -> otomatis lanjut ke autentikasi lokal perangkat
        isConnectedNotifier.value = false;
      }
    }

    // Autentikasi Lokal 100% Offline
    final existingIdx = _localUsers.indexWhere(
      (u) => (u['email']?.toString().toLowerCase() ?? '') == trimmedEmail,
    );
    Map<String, dynamic> localUser;
    if (existingIdx != -1) {
      final storedPass = _localUsers[existingIdx]['password']?.toString() ?? '';
      if (storedPass.isNotEmpty && storedPass != password) {
        const msg = 'Password tidak sesuai dengan akun yang terdaftar di perangkat.';
        lastErrorNotifier.value = msg;
        return {'success': false, 'message': msg};
      }
      localUser = Map<String, dynamic>.from(_localUsers[existingIdx])..remove('password');
    } else {
      localUser = _buildOfflineUser(email: trimmedEmail);
      _localUsers.add({
        ...localUser,
        'password': password,
      });
    }

    ApiConfig.token = 'offline_token_${DateTime.now().millisecondsSinceEpoch}';
    userNotifier.value = localUser;
    isConnectedNotifier.value = false;
    lastErrorNotifier.value = null;
    authStateNotifier.value = true;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'offline': true,
      'data': {
        'token': ApiConfig.token,
        'user': localUser,
      },
    };
  }

  /// Registrasi akun owner dan profil bisnis baru (mendukung 100% offline di perangkat)
  static Future<Map<String, dynamic>> register({
    required String businessName,
    required String name,
    required String email,
    required String password,
    String? address,
    String? phone,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedBusiness = businessName.trim();
    final trimmedName = name.trim();

    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse(ApiConfig.authRegisterUrl);
        final res = await http
            .post(
              uri,
              headers: ApiConfig.defaultHeaders,
              body: jsonEncode({
                'business_name': trimmedBusiness,
                'name': trimmedName,
                'email': trimmedEmail,
                'password': password,
                'address': address?.trim(),
                'phone': phone?.trim(),
              }),
            )
            .timeout(const Duration(seconds: 6));

        final body = jsonDecode(res.body);
        if (res.statusCode == 201 && body['token'] != null) {
          ApiConfig.token = body['token'].toString();
          userNotifier.value = body['user'] is Map
              ? Map<String, dynamic>.from(body['user'] as Map)
              : null;
          isConnectedNotifier.value = true;
          authStateNotifier.value = true;
          dataChangedNotifier.value++;
          await _persistLocalData();
          return {'success': true, 'data': body};
        }
      } catch (_) {
        isConnectedNotifier.value = false;
      }
    }

    // Simpan akun dan identitas toko langsung di perangkat (Offline-First)
    final localUser = _buildOfflineUser(
      email: trimmedEmail,
      name: trimmedName,
      businessName: trimmedBusiness,
    );
    _localUsers.removeWhere(
      (u) => (u['email']?.toString().toLowerCase() ?? '') == trimmedEmail,
    );
    _localUsers.add({
      ...localUser,
      'password': password,
      if (address != null) 'address': address.trim(),
      if (phone != null) 'phone': phone.trim(),
    });

    if (trimmedBusiness.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('store_name', trimmedBusiness);
      } catch (_) {}
    }

    ApiConfig.token = 'offline_token_${DateTime.now().millisecondsSinceEpoch}';
    userNotifier.value = localUser;
    isConnectedNotifier.value = false;
    authStateNotifier.value = true;
    dataChangedNotifier.value++;
    await _persistLocalData();
    return {
      'success': true,
      'offline': true,
      'data': {
        'token': ApiConfig.token,
        'user': localUser,
      },
    };
  }

  /// Logout dan akhiri sesi aktif (data produk & transaksi lokal tetap aman)
  static Future<void> logout() async {
    if (!offlineModeNotifier.value) {
      try {
        if (ApiConfig.token != null && !ApiConfig.token!.startsWith('offline_token_')) {
          final uri = Uri.parse(ApiConfig.authLogoutUrl);
          await http.post(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 4));
        }
      } catch (_) {}
    }
    ApiConfig.token = null;
    userNotifier.value = null;
    authStateNotifier.value = false; // Logout -> kembali ke halaman login
    dataChangedNotifier.value++;
    await _persistLocalData();
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

  /// Ambil daftar produk dari penyimpanan perangkat lokal (atau backend Laravel bila mode online aktif)
  static Future<List<Map<String, dynamic>>> getProducts() async {
    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse('${ApiConfig.productsUrl}?per_page=100');
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
            await _mergeServerProducts(mapped);
            return List<Map<String, dynamic>>.from(_fallbackProducts);
          }
        }

        if (res.statusCode == 401) {
          _handleUnauthorized();
          return List<Map<String, dynamic>>.from(_fallbackProducts);
        }
      } catch (_) {
        isConnectedNotifier.value = false;
      }
    }
    for (final p in _fallbackProducts) {
      p['low'] = isLowStock(p);
    }
    return List<Map<String, dynamic>>.from(_fallbackProducts);
  }

  /// Samakan cache produk lokal dengan data server tanpa membuang
  /// produk yang ditambahkan saat offline (belum ada di server), produk yang dihapus di perangkat,
  /// serta perubahan harga/stok lokal (`local_updated`).
  static Future<void> _mergeServerProducts(List<Map<String, dynamic>> serverItems) async {
    final existingByName = <String, Map<String, dynamic>>{
      for (final p in _fallbackProducts)
        ((p['name'] as String?) ?? '').toLowerCase(): p,
    };

    final filteredServer = serverItems.where((s) {
      final key = ((s['name'] as String?) ?? '').toLowerCase();
      final idKey = s['id']?.toString() ?? '';
      return !_deletedProductKeys.contains(key) &&
          (idKey.isEmpty || !_deletedProductKeys.contains('id:$idKey'));
    });

    final mergedServer = filteredServer.map((s) {
      final key = ((s['name'] as String?) ?? '').toLowerCase();
      final local = existingByName[key];
      if (local != null) {
        if (local['local_updated'] == true) {
          final copy = Map<String, dynamic>.from(local);
          copy['id'] = s['id'] ?? local['id'];
          copy['low'] = isLowStock(copy);
          return copy;
        }
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
        final String serverCat = (s['category'] ?? s['jenis'] ?? '').toString().trim();
        final String localCat = (local['category'] ?? local['jenis'] ?? '').toString().trim();
        if (serverCat.isEmpty && localCat.isNotEmpty) {
          s['category'] = localCat;
          s['jenis'] = localCat;
        }
      }
      final String finalCat = (s['category'] ?? s['jenis'] ?? '').toString().trim();
      if (finalCat.isEmpty) {
        s['category'] = 'Umum';
        s['jenis'] = 'Umum';
      } else {
        s['category'] = finalCat;
        s['jenis'] = finalCat;
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
    await _persistLocalData();
  }

  static Future<int?> _resolveCategoryId(String categoryName) async {
    if (offlineModeNotifier.value) return null;
    final normalized = categoryName.trim();
    if (normalized.isEmpty) return null;
    try {
      final catRes = await http
          .get(Uri.parse(ApiConfig.categoriesUrl), headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 4));
      if (catRes.statusCode == 200) {
        final catBody = jsonDecode(catRes.body);
        final List cats = catBody is List ? catBody : ((catBody['data'] as List?) ?? []);
        final lowerTarget = normalized.toLowerCase();
        for (final c in cats) {
          if (c is Map) {
            final cName = (c['name']?.toString() ?? '').trim().toLowerCase();
            if (cName == lowerTarget) {
              return (c['id'] as num?)?.toInt();
            }
          }
        }
        for (final c in cats) {
          if (c is Map) {
            final cName = (c['name']?.toString() ?? '').trim().toLowerCase();
            if (cName.isNotEmpty &&
                (cName.contains(lowerTarget) || lowerTarget.contains(cName))) {
              return (c['id'] as num?)?.toInt();
            }
          }
        }
      }
      // Jika kategori belum ada di backend, buat otomatis agar kategori tersimpan di DB
      final createRes = await http
          .post(
            Uri.parse(ApiConfig.categoriesUrl),
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode({'name': normalized}),
          )
          .timeout(const Duration(seconds: 4));
      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final createdBody = jsonDecode(createRes.body);
        if (createdBody is Map) {
          final catObj = createdBody['data'] is Map ? createdBody['data'] : createdBody;
          return (catObj['id'] as num?)?.toInt();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Rumus HPP per Unit (UMKM Dagang / Toko Kelontong):
  /// HPP per Unit = Harga Beli per Unit + (Ongkir / Jumlah Barang)
  static int calculateHppPerUnit({
    required int baseCostPrice,
    required int stockCount,
    int shippingCost = 0,
  }) {
    final int safeCost = baseCostPrice < 0 ? 0 : baseCostPrice;
    final int safeShipping = shippingCost < 0 ? 0 : shippingCost;
    if (safeShipping == 0) return safeCost;
    final int divisor = stockCount > 0 ? stockCount : 1;
    return safeCost + (safeShipping / divisor).round();
  }

  /// Tambah produk baru ke penyimpanan perangkat lokal (& backend Laravel bila mode online aktif)
  static Future<bool> addProduct({
    required String name,
    required int price,
    required int stock,
    required String unit,
    String? category,
    int? costPrice,
    int? shippingCost,
    int? minStock,
    int? initialStock,
    String? barcode,
    String? weight,
    String? image,
  }) async {
    final trimmedName = name.trim();
    final effectiveCategory = (category != null && category.trim().isNotEmpty) ? category.trim() : 'Umum';
    final effectiveUnit = unit.trim().isNotEmpty ? unit.trim() : 'pcs';
    final effectiveInitialStock = initialStock ?? stock;
    // Batas stok menipis: di bawah 50% dari stok awal (misal stok awal 100 -> < 50 atau <= 49)
    final effectiveMinStock = minStock ??
        (effectiveInitialStock > 0 ? ((effectiveInitialStock - 1) ~/ 2) : 0);
    final effectiveBaseCostPrice = costPrice ?? 0;
    final effectiveShippingCost = shippingCost ?? 0;
    final effectiveCostPrice = calculateHppPerUnit(
      baseCostPrice: effectiveBaseCostPrice,
      stockCount: effectiveInitialStock,
      shippingCost: effectiveShippingCost,
    );
    final effectiveBarcode = barcode?.trim() ?? '';
    final effectiveWeight = weight?.trim() ?? '';
    final effectiveImage = image?.trim() ?? '';

    _deletedProductKeys.remove(trimmedName.toLowerCase());

    dynamic serverId;
    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse(ApiConfig.productsUrl);

        // Petakan nama kategori pilihan user ke ID kategori di backend Laravel
        final int? categoryId = await _resolveCategoryId(effectiveCategory);

        final payload = {
          'name': trimmedName,
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
              final serverObj = created['data'] is Map ? createdBodyData(created) : created;
              if (serverObj['id'] != null) {
                serverId = serverObj['id'];
              }
            }
          } catch (_) {}
        }
      } catch (_) {
        isConnectedNotifier.value = false;
      }
    }

    // Selalu simpan ke fallback lokal agar instan muncul di UI dan test lolos
    final newMap = <String, dynamic>{
      'id': serverId ?? DateTime.now().millisecondsSinceEpoch,
      'name': trimmedName,
      'price': price,
      'selling_price': price,
      'base_cost_price': effectiveBaseCostPrice,
      'shipping_cost': effectiveShippingCost,
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
    _fallbackProducts.removeWhere(
      (p) =>
          (serverId != null && p['id'] == serverId) ||
          ((p['name'] as String?) ?? '').toLowerCase() == trimmedName.toLowerCase(),
    );
    _fallbackProducts.insert(0, newMap);
    dataChangedNotifier.value++;
    await _persistLocalData();
    return true;
  }

  static Map<dynamic, dynamic> createdBodyData(Map created) {
    return created['data'] as Map;
  }

  /// Perbarui detail produk (termasuk foto, nama, kategori, satuan, stok, harga modal, ongkir & jual)
  static Future<bool> updateProduct({
    required dynamic id,
    String? originalName,
    required String name,
    required int price,
    required int stock,
    required String unit,
    String? category,
    int? costPrice,
    int? shippingCost,
    int? minStock,
    String? barcode,
    String? weight,
    String? image,
  }) async {
    final trimmedName = name.trim();
    final effectiveCategory =
        (category != null && category.trim().isNotEmpty) ? category.trim() : 'Umum';
    final effectiveUnit = unit.trim().isNotEmpty ? unit.trim() : 'pcs';
    final effectiveBaseCostPrice = costPrice ?? 0;
    final effectiveShippingCost = shippingCost ?? 0;
    final effectiveBarcode = barcode?.trim() ?? '';
    final effectiveWeight = weight?.trim() ?? '';
    final effectiveImage = image?.trim() ?? '';

    final idx = _fallbackProducts.indexWhere((p) {
      if (id != null && p['id'] == id) return true;
      if (originalName != null &&
          (p['name'] as String? ?? '').toLowerCase() == originalName.toLowerCase()) {
        return true;
      }
      return false;
    });

    final int prevStock = idx != -1 ? ((_fallbackProducts[idx]['stock'] as num?)?.toInt() ?? 0) : stock;
    final int prevInitial = idx != -1
        ? ((_fallbackProducts[idx]['initial_stock'] as num?)?.toInt() ?? prevStock)
        : stock;
    final int effectiveInitialStock = stock > prevInitial ? stock : prevInitial;
    final int effectiveCostPrice = calculateHppPerUnit(
      baseCostPrice: effectiveBaseCostPrice,
      stockCount: stock > 0 ? stock : effectiveInitialStock,
      shippingCost: effectiveShippingCost,
    );
    final int effectiveMinStock = minStock ??
        (effectiveInitialStock > 0 ? ((effectiveInitialStock - 1) ~/ 2) : 0);

    bool updatedOnServer = false;
    if (!offlineModeNotifier.value) {
      final int? parsedId = id is int ? id : (id is String ? int.tryParse(id) : null);
      if (parsedId != null && parsedId > 0 && parsedId <= 2147483647) {
        try {
          final int? categoryId = await _resolveCategoryId(effectiveCategory);
          final payload = {
            'name': trimmedName,
            'unit': effectiveUnit,
            'cost_price': effectiveCostPrice,
            'selling_price': price,
            'min_stock': effectiveMinStock,
            'category_id': ?categoryId,
            if (effectiveBarcode.isNotEmpty) 'barcode': effectiveBarcode,
          };
          final res = await http
              .put(
                Uri.parse('${ApiConfig.productsUrl}/$parsedId'),
                headers: ApiConfig.defaultHeaders,
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            isConnectedNotifier.value = true;
            updatedOnServer = true;
          }
          if (stock != prevStock) {
            await http
                .post(
                  Uri.parse('${ApiConfig.productsUrl}/$parsedId/adjust'),
                  headers: ApiConfig.defaultHeaders,
                  body: jsonEncode({
                    'actual_stock': stock,
                    'note': 'Edit produk dari aplikasi',
                  }),
                )
                .timeout(const Duration(seconds: 5));
          }
        } catch (_) {}
      }
    }

    final updatedMap = <String, dynamic>{
      if (idx != -1) ..._fallbackProducts[idx],
      'id': idx != -1 ? _fallbackProducts[idx]['id'] : (id ?? DateTime.now().millisecondsSinceEpoch),
      'name': trimmedName,
      'price': price,
      'selling_price': price,
      'base_cost_price': effectiveBaseCostPrice,
      'shipping_cost': effectiveShippingCost,
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
      'local_updated': !updatedOnServer,
    };
    updatedMap['low'] = isLowStock(updatedMap);

    if (idx != -1) {
      _fallbackProducts[idx] = updatedMap;
    } else {
      _fallbackProducts.insert(0, updatedMap);
    }

    dataChangedNotifier.value++;
    await _persistLocalData();
    return true;
  }

  /// Hapus produk dari penyimpanan perangkat lokal (& database backend bila mode online aktif)
  static Future<bool> deleteProduct(dynamic id) async {
    for (final p in _fallbackProducts) {
      if (p['id'] == id || p['name'] == id) {
        final nameKey = ((p['name'] as String?) ?? '').trim().toLowerCase();
        if (nameKey.isNotEmpty) _deletedProductKeys.add(nameKey);
        if (p['id'] != null) _deletedProductKeys.add('id:${p['id']}');
      }
    }
    if (id != null) {
      _deletedProductKeys.add(id.toString().toLowerCase());
      _deletedProductKeys.add('id:$id');
    }

    if (!offlineModeNotifier.value &&
        (id is int || (id is String && int.tryParse(id) != null))) {
      try {
        final parsedId = id is int ? id : int.parse(id as String);
        if (parsedId > 0 && parsedId <= 2147483647) {
          final uri = Uri.parse('${ApiConfig.productsUrl}/$parsedId');
          await http.delete(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 4));
        }
      } catch (_) {}
    }

    _fallbackProducts.removeWhere((p) => p['id'] == id || p['name'] == id);
    dataChangedNotifier.value++;
    await _persistLocalData();
    return true;
  }

  static Map<String, dynamic> _normalizeTransactionItem(dynamic rawItem) {
    if (rawItem is CartItem) {
      final map = rawItem.toMap();
      map['subtotal'] = rawItem.price * rawItem.qty;
      return map;
    }
    final itemMap = rawItem is Map ? Map<String, dynamic>.from(rawItem) : <String, dynamic>{};
    final productMap = itemMap['product'] is Map
        ? Map<String, dynamic>.from(itemMap['product'] as Map)
        : const <String, dynamic>{};

    final int qty = (itemMap['qty'] as num?)?.toInt() ??
        (itemMap['quantity'] as num?)?.toInt() ??
        1;
    final int price = (itemMap['price'] as num?)?.toInt() ??
        (itemMap['unit_price'] as num?)?.toInt() ??
        (productMap['selling_price'] as num?)?.toInt() ??
        (productMap['price'] as num?)?.toInt() ??
        0;
    final int costPrice = (itemMap['cost_price'] as num?)?.toInt() ??
        (productMap['cost_price'] as num?)?.toInt() ??
        0;
    final int subtotal = (itemMap['subtotal'] as num?)?.toInt() ?? (price * qty);
    final String name = (itemMap['name'] ??
            itemMap['item_name'] ??
            productMap['name'] ??
            'Item')
        .toString();
    final String unitRaw = (itemMap['unit'] ?? productMap['unit'] ?? '').toString().trim();
    final String unit = unitRaw.isNotEmpty ? unitRaw : 'pcs';

    return <String, dynamic>{
      if (itemMap['product_id'] != null) 'product_id': itemMap['product_id'],
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'qty': qty,
      'unit': unit,
      'subtotal': subtotal,
      if ((itemMap['category'] ?? productMap['category']) != null)
        'category': itemMap['category'] ?? productMap['category'],
    };
  }

  static String _formatTrxTime(dynamic rawDate, dynamic fallbackTime) {
    final s = rawDate?.toString().trim() ?? '';
    if (s.isNotEmpty) {
      final parsed = DateTime.tryParse(s);
      if (parsed != null) {
        final local = parsed.toLocal();
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      final sepIdx = s.contains('T') ? s.indexOf('T') : s.indexOf(' ');
      if (sepIdx != -1 && s.length >= sepIdx + 6) {
        return s.substring(sepIdx + 1, sepIdx + 6);
      }
    }
    final fb = fallbackTime?.toString().trim() ?? '';
    return fb.isNotEmpty ? fb : '-';
  }

  static String _formatMethodLabel(String rawMethod) {
    switch (rawMethod.trim().toLowerCase()) {
      case 'cash':
      case 'tunai':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'other':
      case 'kasbon':
        return 'Kasbon';
      default:
        return rawMethod.trim().isNotEmpty ? rawMethod.trim() : 'Tunai';
    }
  }

  static List<Map<String, dynamic>> _normalizedLocalTransactions() {
    return _fallbackTransactions.map((t) {
      final copy = Map<String, dynamic>.from(t);
      final rawItems = copy['cartItems'] is List
          ? copy['cartItems'] as List
          : (copy['items'] is List ? copy['items'] as List : const []);
      copy['cartItems'] = rawItems.map(_normalizeTransactionItem).toList();
      copy['synced'] = true;
      return copy;
    }).toList();
  }

  /// Ambil daftar transaksi dari penyimpanan perangkat lokal (atau backend Laravel bila mode online aktif)
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    if (!offlineModeNotifier.value) {
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
            int maxRawIdInBatch = 0;
            for (final t in rawList) {
              if (t is Map) {
                final int? rid = (t['id'] as num?)?.toInt();
                if (rid != null && rid > maxRawIdInBatch) {
                  maxRawIdInBatch = rid;
                }
              }
            }
            // Jika ID transaksi tertinggi di server lebih kecil dari batas reset lama
            // (misal setelah reset server atau migrate:fresh --seed), bersihkan batas reset.
            if (maxRawIdInBatch > 0 &&
                _transactionsResetMaxId > 0 &&
                maxRawIdInBatch < _transactionsResetMaxId) {
              _transactionsResetMaxId = 0;
              _transactionsResetAt = null;
            }

            var filteredRawList = rawList.where((t) {
              if (t is! Map) return false;
              final int? rawId = (t['id'] as num?)?.toInt();
              if (rawId != null) {
                if (rawId > _lastFetchedMaxServerTxId) {
                  _lastFetchedMaxServerTxId = rawId;
                }
                if (_transactionsResetMaxId > 0 && rawId <= _transactionsResetMaxId) {
                  return false;
                }
              }
              if (_transactionsResetAt != null) {
                final rawTs = t['created_at']?.toString() ?? t['transaction_date']?.toString();
                final parsedTs = rawTs != null ? DateTime.tryParse(rawTs)?.toUtc() : null;
                if (parsedTs != null && !parsedTs.isAfter(_transactionsResetAt!)) {
                  return false;
                }
              }
              return true;
            }).toList();

            final serverTransactions = filteredRawList.map((t) {
              final map = Map<String, dynamic>.from(t as Map);
              final int amount = (map['total_amount'] as num?)?.toInt() ??
                  (map['amount'] as num?)?.toInt() ??
                  0;
              final String method = _formatMethodLabel(
                (map['payment_method'] ?? map['method'] ?? 'Tunai').toString(),
              );
              final bool isCompleted = map['status'] == 'completed' || map['synced'] == true;

              String itemsSummary = map['items'] is String ? map['items'] as String : '';
              List<Map<String, dynamic>> cartItems = [];
              if (map['items'] is List) {
                cartItems = (map['items'] as List).map(_normalizeTransactionItem).toList();
              }

              // Jika server menyimpan ringkasan direct_amount atau item kosong, gunakan detail lokal yang cocok bila ada
              final localMatch = _fallbackTransactions.firstWhere(
                (lt) =>
                    (lt['raw_id'] != null && lt['raw_id'] == map['id']) ||
                    (lt['cartItems'] is List &&
                        (lt['cartItems'] as List).isNotEmpty &&
                        (lt['amount'] as num?)?.toInt() == amount &&
                        lt['items']?.toString() == map['note']?.toString()),
                orElse: () => <String, dynamic>{},
              );
              if (localMatch.isNotEmpty &&
                  localMatch['cartItems'] is List &&
                  (localMatch['cartItems'] as List).isNotEmpty) {
                final hasOnlyPlaceholder = cartItems.isEmpty ||
                    (cartItems.length == 1 && cartItems.first['product_id'] == null);
                if (hasOnlyPlaceholder) {
                  cartItems = (localMatch['cartItems'] as List)
                      .map(_normalizeTransactionItem)
                      .toList();
                }
              }

              if (cartItems.isNotEmpty && itemsSummary.isEmpty) {
                itemsSummary = cartItems
                    .map((ci) => '${ci['name']} (${ci['qty']} ${ci['unit']})')
                    .join(', ');
              }

              return {
                'id': map['id'] != null ? 'TRX-0${map['id']}' : 'TRX-${DateTime.now().millisecondsSinceEpoch}',
                'raw_id': map['id'],
                'date': map['transaction_date']?.toString() ?? map['created_at']?.toString() ?? map['date']?.toString() ?? '',
                'time': _formatTrxTime(map['transaction_date'] ?? map['created_at'], map['time']),
                'items': itemsSummary.isNotEmpty ? itemsSummary : 'Transaksi Penjualan',
                'method': method,
                'amount': amount,
                'synced': isCompleted,
                'server_synced': true,
                'cartItems': cartItems,
              };
            }).toList();

            final serverRawIds = serverTransactions
                .map((s) => s['raw_id'])
                .where((id) => id != null)
                .toSet();
            // Jangan pernah menghapus transaksi lokal yang belum punya raw_id server (dibuat saat offline)
            final localOnly = _normalizedLocalTransactions()
                .where((lt) => lt['raw_id'] == null || !serverRawIds.contains(lt['raw_id']))
                .toList();

            final merged = [...localOnly, ...serverTransactions];
            _fallbackTransactions
              ..clear()
              ..addAll(merged);
            await _persistLocalData();
            return merged;
          }
        }

        if (res.statusCode == 401) {
          _handleUnauthorized();
          return _normalizedLocalTransactions();
        }
      } catch (_) {
        isConnectedNotifier.value = false;
      }
    }
    return _normalizedLocalTransactions();
  }

  /// Catat transaksi baru di perangkat lokal (& backend Laravel bila mode online aktif, dengan validasi stok)
  static Future<bool> createTransaction({
    required List<dynamic> cartItems,
    required String itemsSummary,
    required String paymentMethod,
    required int totalAmount,
  }) async {
    // Validasi stok lokal (gabungkan total qty per produk) sebelum memproses transaksi
    final Map<String, int> requestedByKey = {};
    final Map<String, dynamic> pidByKey = {};
    final Map<String, String> displayNameByKey = {};
    final Map<String, int?> maxStockByKey = {};

    for (final item in cartItems) {
      final dynamic pid = (item is CartItem)
          ? item.productId
          : (item is Map ? (item['product_id'] ?? item['id']) : null);
      final String name = ((item is CartItem)
              ? item.name
              : (item is Map ? (item['name']?.toString() ?? '') : ''))
          .trim();
      final int qty = (item is CartItem)
          ? item.qty
          : (item is Map ? ((item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1) : 1);
      final int? maxStock = (item is CartItem)
          ? item.maxStock
          : (item is Map ? (item['max_stock'] as num?)?.toInt() : null);

      final String key = pid != null ? 'id:$pid' : 'name:${name.toLowerCase()}';
      requestedByKey[key] = (requestedByKey[key] ?? 0) + qty;
      pidByKey[key] = pid;
      displayNameByKey[key] = name;
      if (maxStock != null) {
        maxStockByKey[key] = maxStock;
      }
    }

    for (final entry in requestedByKey.entries) {
      final String key = entry.key;
      final int qty = entry.value;
      final dynamic pid = pidByKey[key];
      final String name = displayNameByKey[key] ?? '';

      final idx = _fallbackProducts.indexWhere((p) {
        if (pid != null && p['id'] != null && p['id'].toString() == pid.toString()) {
          return true;
        }
        return (p['name']?.toString().trim().toLowerCase() ?? '') == name.toLowerCase();
      });

      final int? availableStock = idx != -1
          ? (_fallbackProducts[idx]['stock'] as num?)?.toInt() ?? 0
          : maxStockByKey[key];

      if (availableStock != null && qty > availableStock) {
        lastErrorNotifier.value = availableStock <= 0
            ? 'Stok $name sudah habis (0).'
            : 'Stok $name tidak mencukupi (tersisa $availableStock, diminta $qty).';
        return false;
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

    dynamic createdTxId;
    bool serverSynced = false;

    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse(ApiConfig.transactionsUrl);

        // Siapkan payload transaksi sesuai format TransactionController::store
        final List<Map<String, dynamic>> laravelItems = [];
        for (final item in cartItems) {
          dynamic pId;
          int qty = 1;
          String itemName = '';
          int itemPrice = 0;
          int itemCost = 0;
          String itemUnit = 'pcs';
          String itemCategory = 'Umum';

          if (item is CartItem) {
            qty = item.qty;
            pId = item.productId;
            itemName = item.name.trim();
            itemPrice = item.price;
            itemCost = item.costPrice;
            itemUnit = item.unit;
            itemCategory = (item.category ?? 'Umum').trim();
          } else if (item is Map) {
            qty = (item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1;
            pId = item['product_id'] ?? item['id'];
            itemName = (item['name'] ?? '').toString().trim();
            itemPrice = (item['price'] as num?)?.toInt() ?? 0;
            itemCost = (item['cost_price'] as num?)?.toInt() ?? 0;
            itemUnit = (item['unit'] ?? 'pcs').toString();
            itemCategory = (item['category'] ?? item['jenis'] ?? 'Umum').toString();
          }

          Map<String, dynamic>? localProduct;
          if (itemName.isNotEmpty) {
            final idx = _fallbackProducts.indexWhere(
              (p) => ((p['name'] as String?) ?? '').toLowerCase() == itemName.toLowerCase(),
            );
            if (idx != -1) {
              localProduct = _fallbackProducts[idx];
              pId ??= localProduct['id'];
              if (itemPrice <= 0) itemPrice = (localProduct['price'] as num?)?.toInt() ?? 0;
              if (itemCost <= 0) itemCost = (localProduct['cost_price'] as num?)?.toInt() ?? 0;
              if (itemUnit.isEmpty) itemUnit = (localProduct['unit'] ?? 'pcs').toString();
              if (itemCategory.isEmpty) {
                itemCategory = (localProduct['category'] ?? localProduct['jenis'] ?? 'Umum').toString();
              }
            }
          }

          int? parsedPid = pId is int ? pId : (pId is String ? int.tryParse(pId) : null);
          // Jika produk baru masih ber-ID lokal (timestamp > 2^31-1) atau belum punya ID server,
          // sinkronkan produk ke server terlebih dahulu agar tercatat di Produk Terlaris (top_products).
          if ((parsedPid == null || parsedPid <= 0 || parsedPid > 2147483647) &&
              itemName.isNotEmpty &&
              itemPrice > 0) {
            try {
              final int? categoryId = await _resolveCategoryId(itemCategory);
              final int currentStock = (localProduct?['stock'] as num?)?.toInt() ?? qty;
              final int stockToSync = currentStock < qty ? qty : currentStock;
              final createProdRes = await http
                  .post(
                    Uri.parse(ApiConfig.productsUrl),
                    headers: ApiConfig.defaultHeaders,
                    body: jsonEncode({
                      'name': itemName,
                      'unit': itemUnit.isNotEmpty ? itemUnit : 'pcs',
                      'cost_price': itemCost,
                      'selling_price': itemPrice,
                      'price': itemPrice,
                      'stock': stockToSync,
                      'min_stock': stockToSync > 0 ? ((stockToSync - 1) ~/ 2) : 0,
                      'category_id': ?categoryId,
                    }),
                  )
                  .timeout(const Duration(seconds: 4));
              if (createProdRes.statusCode == 200 || createProdRes.statusCode == 201) {
                final createdBody = jsonDecode(createProdRes.body);
                if (createdBody is Map) {
                  final serverObj = createdBody['data'] is Map ? createdBody['data'] : createdBody;
                  final int? newServerPid = (serverObj['id'] as num?)?.toInt();
                  if (newServerPid != null && newServerPid > 0) {
                    parsedPid = newServerPid;
                    if (localProduct != null) {
                      localProduct['id'] = newServerPid;
                    }
                  }
                }
              }
            } catch (_) {}
          }

          // ID <= 2^31-1 adalah ID produk valid di DB server
          if (parsedPid != null && parsedPid > 0 && parsedPid <= 2147483647) {
            laravelItems.add({'product_id': parsedPid, 'quantity': qty});
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
            createdTxId = txId;
            if (txId != null) {
              // Aplikasi pencatatan hanya menyimpan transaksi (tanpa input uang tunai diterima),
              // sehingga semua metode (Tunai/QRIS/Kasbon) dikonfirmasi seragam via /confirm.
              final confirmUri = Uri.parse('${ApiConfig.transactionsUrl}/$txId/confirm');
              final confirmRes = await http
                  .post(
                    confirmUri,
                    headers: ApiConfig.defaultHeaders,
                    body: jsonEncode({'payment_method': backendMethod}),
                  )
                  .timeout(const Duration(seconds: 5));
              if (confirmRes.statusCode == 200) {
                serverSynced = true;
              } else if (confirmRes.statusCode == 422) {
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
    }

    // Deduct stock from fallbackProducts & update low stock status (< 50% dari initial_stock)
    for (final item in cartItems) {
      final dynamic pid = (item is CartItem)
          ? item.productId
          : (item is Map ? (item['product_id'] ?? item['id']) : null);
      final String name = ((item is CartItem)
              ? item.name
              : (item is Map ? (item['name']?.toString() ?? '') : ''))
          .trim();
      final int qty = (item is CartItem)
          ? item.qty
          : (item is Map ? ((item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1) : 1);

      final idx = _fallbackProducts.indexWhere((p) {
        if (pid != null && p['id'] != null && p['id'].toString() == pid.toString()) {
          return true;
        }
        return (p['name']?.toString().trim().toLowerCase() ?? '') == name.toLowerCase();
      });
      if (idx != -1) {
        final currentStock = (_fallbackProducts[idx]['stock'] as num?)?.toInt() ?? 0;
        final initialStock = (_fallbackProducts[idx]['initial_stock'] as num?)?.toInt() ?? currentStock;
        final newStock = (currentStock - qty).clamp(0, 999999);
        _fallbackProducts[idx]['initial_stock'] = initialStock;
        _fallbackProducts[idx]['stock'] = newStock;
        _fallbackProducts[idx]['low'] = isLowStock(_fallbackProducts[idx]);
      }
    }

    // Simpan rincian produk transaksi secara lengkap di cache lokal & SharedPreferences
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final serializedItems = cartItems.map((i) {
      final Map<String, dynamic> map = _normalizeTransactionItem(i);
      final String pName = (map['name'] ?? '').toString();
      final match = _fallbackProducts.firstWhere(
        (p) => (p['name'] as String? ?? '').toLowerCase() == pName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        if (((map['cost_price'] as num?)?.toInt() ?? 0) == 0) {
          map['cost_price'] = (match['cost_price'] as num?)?.toInt() ?? 0;
        }
        if (map['unit'] == null || map['unit'].toString().isEmpty) {
          map['unit'] = match['unit'] ?? 'pcs';
        }
        if (map['category'] == null || map['category'].toString().isEmpty) {
          map['category'] = match['category'] ?? match['jenis'] ?? 'Umum';
        }
      }
      return map;
    }).toList();

    _fallbackTransactions.insert(0, {
      'id': createdTxId != null ? 'TRX-0$createdTxId' : 'TRX-0${_fallbackTransactions.length + 1}',
      if (createdTxId != null) 'raw_id': createdTxId,
      'time': timeStr,
      'date': now.toIso8601String().substring(0, 10),
      'items': itemsSummary,
      'method': paymentMethod,
      'amount': totalAmount,
      'synced': true,
      'server_synced': serverSynced,
      'cartItems': serializedItems,
    });
    dataChangedNotifier.value++;
    await _persistLocalData();
    return true;
  }

  /// Ambil data statistik ringkasan dashboard dari perangkat lokal (& backend Laravel bila mode online aktif)
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final int localOmzet = _fallbackTransactions.fold(0, (sum, t) => sum + ((t['amount'] as int?) ?? 0));
    final int localTotalTrx = _fallbackTransactions.length;
    final int localStokMenipis = _fallbackProducts.where((p) => isLowStock(p)).length;
    final List<Map<String, dynamic>> localTopProducts =
        (_localSalesTrends()['top_products'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[];

    if (!offlineModeNotifier.value) {
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

            final List<Map<String, dynamic>> mergedTopProducts = _mergeTopProducts(
              body['top_products'],
              localTopProducts,
            );

            String produkTerlaris = '-';
            if (mergedTopProducts.isNotEmpty) {
              produkTerlaris = mergedTopProducts.first['name']?.toString() ?? '-';
            } else if (body['produk_terlaris'] != null) {
              produkTerlaris = body['produk_terlaris'].toString();
            }

            final int totalProduk = _fallbackProducts.isNotEmpty ? _fallbackProducts.length : ((body['total_produk'] as int?) ?? 0);

            return {
              'omzet': omzet,
              'total_transaksi': totalTrx,
              'produk_terlaris': produkTerlaris,
              'top_products': mergedTopProducts,
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
    }

    // Kalkulasi dinamis dari fallback lokal
    int omzet = localOmzet;
    int totalTrx = localTotalTrx;
    int totalProduk = _fallbackProducts.length;
    int stokMenipis = localStokMenipis;

    String produkTerlaris = '-';
    if (localTopProducts.isNotEmpty) {
      produkTerlaris = localTopProducts.first['name']?.toString() ?? '-';
    }

    return {
      'omzet': omzet,
      'total_transaksi': totalTrx,
      'produk_terlaris': produkTerlaris,
      'top_products': localTopProducts,
      'stok_menipis': stokMenipis,
      'total_produk': totalProduk,
    };
  }

  /// Gabungkan daftar produk terlaris dari server dan lokal berdasarkan jumlah terjual tertinggi (total_sold).
  static List<Map<String, dynamic>> _mergeTopProducts(
    dynamic serverRaw,
    List<Map<String, dynamic>> localTop,
  ) {
    final Map<String, Map<String, dynamic>> byName = {};

    if (serverRaw is List) {
      for (final item in serverRaw) {
        if (item is Map) {
          final String name = (item['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final String key = name.toLowerCase();
          byName[key] = {
            'product_id': item['product_id'],
            'name': name,
            'unit': (item['unit'] ?? 'pcs').toString(),
            'category': (item['category'] ?? '').toString(),
            'total_sold': (item['total_sold'] as num?)?.toInt() ?? 0,
            'total_revenue': (item['total_revenue'] as num?)?.toInt() ?? 0,
          };
        }
      }
    }

    for (final local in localTop) {
      final String name = (local['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final String key = name.toLowerCase();
      final int localSold = (local['total_sold'] as num?)?.toInt() ?? 0;
      final int localRev = (local['total_revenue'] as num?)?.toInt() ?? 0;
      final existing = byName[key];
      if (existing == null || localSold > ((existing['total_sold'] as num?)?.toInt() ?? 0)) {
        byName[key] = {
          'product_id': existing?['product_id'] ?? local['product_id'],
          'name': name,
          'unit': (local['unit'] ?? existing?['unit'] ?? 'pcs').toString(),
          'category': (local['category'] ?? existing?['category'] ?? '').toString(),
          'total_sold': localSold,
          'total_revenue': localRev > ((existing?['total_revenue'] as num?)?.toInt() ?? 0)
              ? localRev
              : ((existing?['total_revenue'] as num?)?.toInt() ?? 0),
        };
      }
    }

    final merged = byName.values.where((p) => ((p['total_sold'] as num?)?.toInt() ?? 0) > 0).toList()
      ..sort((a, b) {
        final int cmpSold = ((b['total_sold'] as num?)?.toInt() ?? 0)
            .compareTo((a['total_sold'] as num?)?.toInt() ?? 0);
        if (cmpSold != 0) return cmpSold;
        return ((b['total_revenue'] as num?)?.toInt() ?? 0)
            .compareTo((a['total_revenue'] as num?)?.toInt() ?? 0);
      });
    return merged.take(5).toList();
  }

  /// Ambil laporan laba-rugi (penjualan vs pembelian/beban) dari penyimpanan perangkat lokal
  /// (atau backend bila mode online aktif).
  static Future<Map<String, dynamic>> getProfitLossReport({String period = 'monthly'}) async {
    if (!offlineModeNotifier.value) {
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
    // Laba Kotor = Total Omzet (Penjualan) - Total HPP Barang Terjual
    final int grossProfit = revenue - cogs;
    // Laba Bersih = Laba Kotor - Biaya Operasional Tambahan
    final int netProfit = grossProfit;
    // Margin Kotor (%) = ((Omzet - HPP) / Omzet) * 100%
    final double grossMarginPct =
        revenue > 0 ? (grossProfit / revenue) * 100.0 : 0.0;
    // Markup (%) = ((Omzet - HPP) / HPP) * 100%
    final double markupPct = cogs > 0 ? (grossProfit / cogs) * 100.0 : 0.0;
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
        'gross_margin_percentage': grossMarginPct,
        'markup_percentage': markupPct,
        'operational_expenses': purchases,
        'net_profit': netProfit,
        'net_margin_percentage':
            revenue > 0 ? (netProfit / revenue) * 100.0 : 0.0,
      },
      'expense_categories': expenseCategories,
      'product_breakdown': <dynamic>[],
    };
  }

  /// Ambil tren penjualan (7 hari / 30 hari / bulanan) & produk terlaris
  /// dari penyimpanan perangkat lokal (atau backend bila mode online aktif).
  static Future<Map<String, dynamic>> getSalesTrends() async {
    final localTrends = _localSalesTrends();
    final List<Map<String, dynamic>> localTop =
        (localTrends['top_products'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[];

    if (!offlineModeNotifier.value) {
      try {
        final uri = Uri.parse(ApiConfig.dashboardUrl);
        final res = await http.get(uri, headers: ApiConfig.defaultHeaders).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body is Map) {
            isConnectedNotifier.value = true;
            lastErrorNotifier.value = null;
            final trend = body['sales_trend'];
            final List serverTrend7 = (trend is Map && trend['last_7_days'] is List)
                ? trend['last_7_days'] as List
                : <dynamic>[];
            final List serverTrend30 = (trend is Map && trend['last_30_days'] is List)
                ? trend['last_30_days'] as List
                : <dynamic>[];
            final List serverMonthly = (trend is Map && trend['monthly'] is List)
                ? trend['monthly'] as List
                : <dynamic>[];

            int sumSold(List list) => list.fold<int>(
                  0,
                  (s, e) => s + (e is Map ? ((e['sold'] ?? e['total'] ?? 0) as num).toInt() : 0),
                );

            final mergedTop = _mergeTopProducts(body['top_products'], localTop);

            return {
              'trend7': sumSold(serverTrend7) > 0 ? serverTrend7 : (localTrends['trend7'] ?? serverTrend7),
              'trend30': sumSold(serverTrend30) > 0 ? serverTrend30 : (localTrends['trend30'] ?? serverTrend30),
              'monthly': sumSold(serverMonthly) > 0 ? serverMonthly : (localTrends['monthly'] ?? serverMonthly),
              'top_products': mergedTop,
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
    }

    return localTrends;
  }

  /// Kalkulasi tren produk terjual dari transaksi fallback lokal (mode offline)
  static Map<String, dynamic> _localSalesTrends() {
    final byDay = <String, int>{};
    final byMonth = <String, int>{};
    final revByDay = <String, int>{};
    final revByMonth = <String, int>{};
    final countByDay = <String, int>{};
    final countByMonth = <String, int>{};
    final Map<String, Map<String, dynamic>> productAgg = {};

    for (final t in _fallbackTransactions) {
      final int amount = (t['amount'] as int?) ?? 0;
      final String date = t['date']?.toString() ?? '';
      final items = t['cartItems'] as List? ?? [];
      int trxSold = 0;

      for (final item in items) {
        if (item is Map) {
          final int qty = (item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1;
          trxSold += qty;

          final String name = (item['name'] ?? '').toString();
          if (name.isEmpty) continue;
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

      if (trxSold == 0 && amount > 0) {
        trxSold = 1;
      }

      if (date.isNotEmpty) {
        byDay[date] = (byDay[date] ?? 0) + trxSold;
        revByDay[date] = (revByDay[date] ?? 0) + amount;
        countByDay[date] = (countByDay[date] ?? 0) + 1;
        if (date.length >= 7) {
          final monthKey = date.substring(0, 7);
          byMonth[monthKey] = (byMonth[monthKey] ?? 0) + trxSold;
          revByMonth[monthKey] = (revByMonth[monthKey] ?? 0) + amount;
          countByMonth[monthKey] = (countByMonth[monthKey] ?? 0) + 1;
        }
      }
    }

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => (b['total_sold'] as int).compareTo(a['total_sold'] as int));

    List<Map<String, dynamic>> toList(
      Map<String, int> soldMap,
      Map<String, int> revMap,
      Map<String, int> countMap,
      String keyName,
    ) {
      final keys = soldMap.keys.toList()..sort();
      return keys
          .map((k) => {
                keyName: k,
                'total': soldMap[k] ?? 0,
                'sold': soldMap[k] ?? 0,
                'revenue': revMap[k] ?? 0,
                'count': countMap[k] ?? 0,
              })
          .toList();
    }

    return {
      'offline': true,
      'trend7': toList(byDay, revByDay, countByDay, 'date'),
      'trend30': toList(byDay, revByDay, countByDay, 'date'),
      'monthly': toList(byMonth, revByMonth, countByMonth, 'month'),
      'top_products': topProducts.take(5).toList(),
      'today': <String, dynamic>{},
    };
  }

  /// Filter daftar transaksi berdasarkan periode unduhan:
  /// 'semua', 'minggu' (7 hari terakhir), 'bulan' (bulan berjalan), 'tahun' (tahun berjalan).
  static List<Map<String, dynamic>> filterTransactionsByPeriod(
    List<Map<String, dynamic>> transactions,
    String period, {
    DateTime? referenceDate,
  }) {
    final normalized = period.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'semua' || normalized == 'all') {
      return List<Map<String, dynamic>>.from(transactions);
    }

    final now = (referenceDate ?? DateTime.now()).toLocal();
    late final DateTime start;
    late final DateTime end;

    if (normalized == 'minggu' || normalized == 'perminggu' || normalized == 'weekly') {
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (normalized == 'bulan' || normalized == 'perbulan' || normalized == 'monthly') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    } else if (normalized == 'tahun' || normalized == 'pertahun' || normalized == 'yearly') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    } else {
      return List<Map<String, dynamic>>.from(transactions);
    }

    return transactions.where((trx) {
      final rawDate = (trx['transaction_date'] ?? trx['created_at'] ?? trx['date'])?.toString().trim() ?? '';
      if (rawDate.isEmpty) return false;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) return false;
      final localDate = (rawDate.contains('T') || rawDate.contains(':')) ? parsed.toLocal() : parsed;
      return !localDate.isBefore(start) && !localDate.isAfter(end);
    }).toList();
  }

  /// Buat data export CSV untuk fitur Cadangkan Data (P0):
  /// Menggunakan header `sep=,` dan CRLF agar Excel di Windows otomatis memisah kolom ke sel berbeda.
  static String buildTransactionsExportCsv(List<Map<String, dynamic>> transactions) {
    String csvEscape(dynamic val) {
      final s = (val ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }

    String formatExportWaktu(String datePart, String timePart) {
      if (datePart.isNotEmpty) {
        final parsed = DateTime.tryParse(datePart);
        if (parsed != null && (datePart.contains('T') || datePart.contains(':'))) {
          final local = parsed.toLocal();
          final y = local.year.toString().padLeft(4, '0');
          final m = local.month.toString().padLeft(2, '0');
          final d = local.day.toString().padLeft(2, '0');
          final hh = local.hour.toString().padLeft(2, '0');
          final mm = local.minute.toString().padLeft(2, '0');
          return '$y-$m-$d $hh:$mm';
        }
        return (datePart.contains('T') || datePart.contains(' '))
            ? datePart
            : '$datePart $timePart';
      }
      return timePart;
    }

    final buffer = StringBuffer();
    buffer.write('sep=,\r\n');
    buffer.write(
      'id_transaksi,waktu_transaksi,jenis_pembayaran,nama_produk,qty,harga_satuan_idr,total_transaksi_idr\r\n',
    );

    for (final trx in transactions) {
      final id = trx['id'] ?? '-';
      final datePart = trx['date']?.toString() ?? '';
      final timePart = trx['time']?.toString() ?? '-';
      final waktu = formatExportWaktu(datePart, timePart);
      final method = trx['method'] ?? '-';
      final totalIdr = trx['amount'] ?? 0;
      final items = trx['cartItems'] as List? ?? [];

      if (items.isEmpty) {
        final row = [
          csvEscape(id),
          csvEscape(waktu),
          csvEscape(method),
          csvEscape(trx['items'] ?? '-'),
          1,
          totalIdr,
          totalIdr,
        ].join(',');
        buffer.write('$row\r\n');
      } else {
        for (final item in items) {
          if (item is Map) {
            final pName = item['name'] ?? item['item_name'] ?? item['product']?['name'] ?? 'Item';
            final qty = item['qty'] ?? item['quantity'] ?? 1;
            final unitPrice = item['price'] ?? item['unit_price'] ?? item['product']?['selling_price'] ?? 0;
            final row = [
              csvEscape(id),
              csvEscape(waktu),
              csvEscape(method),
              csvEscape(pName),
              qty,
              unitPrice,
              totalIdr,
            ].join(',');
            buffer.write('$row\r\n');
          }
        }
      }
    }

    return buffer.toString();
  }
}
