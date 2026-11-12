import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum DeviceTarget {
  emulator,
  physicalPhone,
  desktopOrWeb,
  custom,
}

class ApiConfig {
  // IP default Wi-Fi laptop & Port backend Laravel
  static const String defaultWifiIp = '192.168.1.68';
  static const String defaultPort = '8000';
  static const String defaultPath = '/api/v1';

  static const String emulatorBaseUrl = 'http://10.0.2.2:$defaultPort$defaultPath';
  static const String wifiBaseUrl = 'http://$defaultWifiIp:$defaultPort$defaultPath';
  static const String localhostBaseUrl = 'http://127.0.0.1:$defaultPort$defaultPath';

  // State reaktif agar UI otomatis update saat konfigurasi berubah
  static final ValueNotifier<String> baseUrlNotifier = ValueNotifier<String>(_getInitialBaseUrl());
  static final ValueNotifier<DeviceTarget> targetNotifier = ValueNotifier<DeviceTarget>(_getInitialTarget());
  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);

  static String get baseUrl => baseUrlNotifier.value;
  static DeviceTarget get target => targetNotifier.value;
  static String? get token => tokenNotifier.value;
  static set token(String? val) => tokenNotifier.value = val;

  static Map<String, String> get defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token!.trim()}';
    }
    return headers;
  }

  static String _getInitialBaseUrl() {
    if (kIsWeb) return localhostBaseUrl;
    try {
      if (Platform.isAndroid) {
        // Default untuk Android: emulator (10.0.2.2:8000)
        return emulatorBaseUrl;
      }
    } catch (_) {}
    return localhostBaseUrl;
  }

  static DeviceTarget _getInitialTarget() {
    if (kIsWeb) return DeviceTarget.desktopOrWeb;
    try {
      if (Platform.isAndroid) return DeviceTarget.emulator;
    } catch (_) {}
    return DeviceTarget.desktopOrWeb;
  }

  static void setTarget(DeviceTarget newTarget, {String? customIp, String? customPort}) {
    targetNotifier.value = newTarget;
    final port = (customPort != null && customPort.trim().isNotEmpty) ? customPort.trim() : defaultPort;

    switch (newTarget) {
      case DeviceTarget.emulator:
        baseUrlNotifier.value = 'http://10.0.2.2:$port$defaultPath';
        break;
      case DeviceTarget.physicalPhone:
        final ip = (customIp != null && customIp.trim().isNotEmpty) ? customIp.trim() : defaultWifiIp;
        baseUrlNotifier.value = 'http://$ip:$port$defaultPath';
        break;
      case DeviceTarget.desktopOrWeb:
        baseUrlNotifier.value = 'http://127.0.0.1:$port$defaultPath';
        break;
      case DeviceTarget.custom:
        if (customIp != null && customIp.trim().isNotEmpty) {
          final trimmed = customIp.trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            baseUrlNotifier.value = trimmed.endsWith(defaultPath) ? trimmed : '$trimmed$defaultPath';
          } else {
            baseUrlNotifier.value = 'http://$trimmed:$port$defaultPath';
          }
        }
        break;
    }
  }

  static void setCustomUrl(String url) {
    targetNotifier.value = DeviceTarget.custom;
    baseUrlNotifier.value = url.trim();
  }

  // Endpoints RESTful Laravel 11
  static String get healthUrl => '$baseUrl/health';
  static String get testUrl => healthUrl; // Kompatibilitas mundur
  static String get authLoginUrl => '$baseUrl/auth/login';
  static String get authRegisterUrl => '$baseUrl/auth/register';
  static String get authLogoutUrl => '$baseUrl/auth/logout';
  static String get authProfileUrl => '$baseUrl/auth/profile';
  static String get userUrl => '$baseUrl/user';
  static String get categoriesUrl => '$baseUrl/categories';
  static String get productsUrl => '$baseUrl/products';
  static String get produkUrl => productsUrl; // Kompatibilitas mundur
  static String get transactionsUrl => '$baseUrl/transactions';
  static String get transaksiUrl => transactionsUrl; // Kompatibilitas mundur
  static String get dashboardUrl => '$baseUrl/dashboard/summary';
  static String get expensesUrl => '$baseUrl/expenses';
  static String get capitalUrl => '$baseUrl/capital';
  static String get plansUrl => '$baseUrl/plans';

  static String barcodeUrl(String barcode) => '$baseUrl/products/barcode/$barcode';
  static String qrisUrl(dynamic id) => '$baseUrl/transactions/$id/qris';
  static String payCashUrl(dynamic id) => '$baseUrl/transactions/$id/pay/cash';
  static String receiptUrl(dynamic id) => '$baseUrl/transactions/$id/receipt';
}
