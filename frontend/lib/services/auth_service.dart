import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/user_model.dart';
import 'api_config.dart';

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyBusiness = 'auth_business';

  // State reaktif
  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);
  static final ValueNotifier<String?> tokenNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> isAuthenticatingNotifier =
      ValueNotifier<bool>(false);

  static UserModel? get currentUser => currentUserNotifier.value;
  static String? get token => tokenNotifier.value;
  static bool get isLoggedIn => currentUserNotifier.value != null;

  /// Inisialisasi auth state dari SharedPreferences saat aplikasi start
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      final savedUserJson = prefs.getString(_keyUser);

      if (savedToken != null && savedToken.isNotEmpty && savedUserJson != null) {
        tokenNotifier.value = savedToken;
        final userMap = jsonDecode(savedUserJson) as Map<String, dynamic>;
        currentUserNotifier.value = UserModel.fromJson(userMap);

        // Validasi dan refresh profil user secara asinkron jika online
        _refreshProfileSilently();
      }
    } catch (e) {
      debugPrint('AuthService.init error: $e');
    }
  }

  /// Header autentikasi untuk request REST API Laravel Sanctum
  static Map<String, String> get authHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Login ke REST API (POST /api/v1/auth/login)
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    isAuthenticatingNotifier.value = true;
    try {
      final uri = Uri.parse(ApiConfig.authLoginUrl);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body is Map) {
        final authToken = body['token'] as String?;
        final userRaw = body['user'] as Map<String, dynamic>?;

        if (authToken != null && userRaw != null) {
          final user = UserModel.fromJson(userRaw);
          final business = user.business ??
              (body['business'] is Map<String, dynamic>
                  ? BusinessModel.fromJson(body['business'] as Map<String, dynamic>)
                  : null);

          // Simpan session
          await _saveSession(token: authToken, user: user, business: business);

          return AuthResult.success(
            message: 'Berhasil masuk!',
            user: user,
            business: business,
            token: authToken,
          );
        }
      }

      // Handle response error dari Laravel (422 / 401 / 403 / 500)
      String errorMsg = 'Gagal masuk. Periksa kembali email dan kata sandi Anda.';
      Map<String, dynamic>? errors;

      if (body is Map) {
        if (body['message'] is String && (body['message'] as String).isNotEmpty) {
          errorMsg = body['message'];
        }
        if (body['errors'] is Map) {
          errors = Map<String, dynamic>.from(body['errors'] as Map);
          final firstKey = errors.keys.firstOrNull;
          if (firstKey != null && errors[firstKey] is List && (errors[firstKey] as List).isNotEmpty) {
            errorMsg = errors[firstKey][0].toString();
          }
        }
      }

      return AuthResult.failure(message: errorMsg, errors: errors);
    } on TimeoutException {
      return AuthResult.failure(
        message: 'Koneksi waktu habis. Pastikan backend server aktif di ${ApiConfig.baseUrl}.',
      );
    } catch (e) {
      return AuthResult.failure(
        message: 'Gagal terhubung ke server (${ApiConfig.baseUrl}): $e',
      );
    } finally {
      isAuthenticatingNotifier.value = false;
    }
  }

  /// Register akun dan bisnis baru ke REST API (POST /api/v1/auth/register)
  static Future<AuthResult> register({
    required String businessName,
    required String name,
    required String email,
    required String password,
    String? address,
    String? phone,
  }) async {
    isAuthenticatingNotifier.value = true;
    try {
      final uri = Uri.parse(ApiConfig.authRegisterUrl);
      final payload = {
        'business_name': businessName.trim(),
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      };

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);

      if ((response.statusCode == 201 || response.statusCode == 200) && body is Map) {
        final authToken = body['token'] as String?;
        final userRaw = body['user'] as Map<String, dynamic>?;
        final businessRaw = body['business'] as Map<String, dynamic>?;

        if (authToken != null && userRaw != null) {
          final business = businessRaw != null
              ? BusinessModel.fromJson(businessRaw)
              : null;
          final user = UserModel.fromJson(userRaw).copyWith(business: business);

          // Simpan session
          await _saveSession(token: authToken, user: user, business: business);

          return AuthResult.success(
            message: 'Registrasi bisnis & akun berhasil!',
            user: user,
            business: business,
            token: authToken,
          );
        }
      }

      // Handle validasi error dari Laravel
      String errorMsg = 'Registrasi gagal. Silakan periksa kembali formulir.';
      Map<String, dynamic>? errors;

      if (body is Map) {
        if (body['message'] is String && (body['message'] as String).isNotEmpty) {
          errorMsg = body['message'];
        }
        if (body['errors'] is Map) {
          errors = Map<String, dynamic>.from(body['errors'] as Map);
          final firstKey = errors.keys.firstOrNull;
          if (firstKey != null && errors[firstKey] is List && (errors[firstKey] as List).isNotEmpty) {
            errorMsg = errors[firstKey][0].toString();
          }
        }
      }

      return AuthResult.failure(message: errorMsg, errors: errors);
    } on TimeoutException {
      return AuthResult.failure(
        message: 'Koneksi waktu habis saat mendaftarkan akun. Cek backend server di ${ApiConfig.baseUrl}.',
      );
    } catch (e) {
      return AuthResult.failure(
        message: 'Gagal terhubung ke REST API (${ApiConfig.baseUrl}): $e',
      );
    } finally {
      isAuthenticatingNotifier.value = false;
    }
  }

  /// Logout (POST /api/v1/auth/logout) dan bersihkan token lokal
  static Future<void> logout() async {
    final currentToken = token;
    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        final uri = Uri.parse(ApiConfig.authLogoutUrl);
        await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $currentToken',
              },
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Abaikan error jaringan saat logout
      }
    }

    await _clearSession();
  }

  /// Refresh profil user dari REST API (GET /api/v1/user)
  static Future<UserModel?> fetchUserProfile() async {
    final currentToken = token;
    if (currentToken == null || currentToken.isEmpty) return null;

    try {
      final uri = Uri.parse(ApiConfig.userProfileUrl);
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final user = UserModel.fromJson(body);
          currentUserNotifier.value = user;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyUser, jsonEncode(user.toJson()));
          return user;
        }
      }
    } catch (e) {
      debugPrint('AuthService.fetchUserProfile error: $e');
    }
    return currentUserNotifier.value;
  }

  /// Masuk dengan mode Demo / Offline Tamu (agar UI tetap bisa ditinjau kapan saja)
  static Future<void> loginAsGuest({
    String role = 'owner',
    String storeName = 'Warung Demo Kasir',
    String userName = 'Kasir Tamu',
  }) async {
    final business = BusinessModel(
      id: 999,
      name: storeName,
      address: 'Jl. Demo POS No. 1',
      phone: '08123456789',
    );
    final user = UserModel(
      id: 999,
      businessId: business.id,
      name: userName,
      email: 'demo@kasir.local',
      role: role,
      business: business,
    );

    await _saveSession(token: 'mock-offline-token', user: user, business: business);
  }

  static Future<void> _refreshProfileSilently() async {
    try {
      await fetchUserProfile();
    } catch (_) {}
  }

  static Future<void> _saveSession({
    required String token,
    required UserModel user,
    BusinessModel? business,
  }) async {
    tokenNotifier.value = token;
    currentUserNotifier.value = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    if (business != null) {
      await prefs.setString(_keyBusiness, jsonEncode(business.toJson()));
    }
  }

  static Future<void> _clearSession() async {
    tokenNotifier.value = null;
    currentUserNotifier.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyBusiness);
  }
}
