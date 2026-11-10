import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum DeviceTarget {
  emulator,
  physicalPhone,
  desktopOrWeb,
  custom,
}

class ApiConfig {
  // IP default Wi-Fi laptop & port Laravel
  static const String defaultWifiIp = '192.168.1.68';
  static const String defaultPort = '8000';
  static const String defaultPath = '/api/v1';

  static String get emulatorBaseUrl => 'http://10.0.2.2:$defaultPort$defaultPath';
  static String get wifiBaseUrl => 'http://$defaultWifiIp:$defaultPort$defaultPath';
  static String get localhostBaseUrl => 'http://127.0.0.1:$defaultPort$defaultPath';

  // State reaktif agar UI otomatis update saat baseUrl berubah
  static final ValueNotifier<String> baseUrlNotifier =
      ValueNotifier<String>(_getInitialBaseUrl());
  static final ValueNotifier<DeviceTarget> targetNotifier =
      ValueNotifier<DeviceTarget>(_getInitialTarget());

  static String get baseUrl => baseUrlNotifier.value;
  static DeviceTarget get target => targetNotifier.value;

  static String _getInitialBaseUrl() {
    if (kIsWeb) return localhostBaseUrl;
    try {
      if (Platform.isAndroid) {
        // Default untuk Android: emulator (10.0.2.2)
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
    final port = customPort?.trim().isNotEmpty == true ? customPort!.trim() : defaultPort;
    final portSuffix = port.isNotEmpty ? ':$port' : '';

    switch (newTarget) {
      case DeviceTarget.emulator:
        baseUrlNotifier.value = 'http://10.0.2.2$portSuffix$defaultPath';
        break;
      case DeviceTarget.physicalPhone:
        final ip = customIp?.trim().isNotEmpty == true ? customIp!.trim() : defaultWifiIp;
        baseUrlNotifier.value = 'http://$ip$portSuffix$defaultPath';
        break;
      case DeviceTarget.desktopOrWeb:
        baseUrlNotifier.value = 'http://127.0.0.1$portSuffix$defaultPath';
        break;
      case DeviceTarget.custom:
        if (customIp != null && customIp.isNotEmpty) {
          final trimmed = customIp.trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            baseUrlNotifier.value = trimmed.endsWith('/')
                ? trimmed.substring(0, trimmed.length - 1)
                : trimmed;
          } else {
            baseUrlNotifier.value = 'http://$trimmed$portSuffix$defaultPath';
          }
        }
        break;
    }
  }

  static void setCustomUrl(String url) {
    targetNotifier.value = DeviceTarget.custom;
    final trimmed = url.trim();
    baseUrlNotifier.value = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  // REST API Endpoints (Laravel Sanctum v1)
  static String get healthUrl => '$baseUrl/health';
  static String get authLoginUrl => '$baseUrl/auth/login';
  static String get authRegisterUrl => '$baseUrl/auth/register';
  static String get authLogoutUrl => '$baseUrl/auth/logout';
  static String get userProfileUrl => '$baseUrl/user';
  static String get categoriesUrl => '$baseUrl/categories';
  static String get productsUrl => '$baseUrl/products';
  static String get transactionsUrl => '$baseUrl/transactions';
  static String get dashboardUrl => '$baseUrl/dashboard/summary';

  // Legacy / fallback endpoint compatibility
  static String get testUrl => healthUrl;
  static String get produkUrl => productsUrl;
  static String get transaksiUrl => transactionsUrl;
}
