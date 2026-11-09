import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum DeviceTarget {
  emulator,
  physicalPhone,
  desktopOrWeb,
  custom,
}

class ApiConfig {
  // IP default Wi-Fi laptop saat ini
  static const String defaultWifiIp = '192.168.1.68';
  static const String defaultPath = '/api_warung';

  static const String emulatorBaseUrl = 'http://10.0.2.2$defaultPath';
  static const String wifiBaseUrl = 'http://$defaultWifiIp$defaultPath';
  static const String localhostBaseUrl = 'http://127.0.0.1$defaultPath';

  // State reaktif agar UI otomatis update saat baseUrl berubah
  static final ValueNotifier<String> baseUrlNotifier = ValueNotifier<String>(_getInitialBaseUrl());
  static final ValueNotifier<DeviceTarget> targetNotifier = ValueNotifier<DeviceTarget>(_getInitialTarget());

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

  static void setTarget(DeviceTarget newTarget, {String? customIp}) {
    targetNotifier.value = newTarget;
    switch (newTarget) {
      case DeviceTarget.emulator:
        baseUrlNotifier.value = emulatorBaseUrl;
        break;
      case DeviceTarget.physicalPhone:
        final ip = customIp?.trim().isNotEmpty == true ? customIp!.trim() : defaultWifiIp;
        baseUrlNotifier.value = 'http://$ip$defaultPath';
        break;
      case DeviceTarget.desktopOrWeb:
        baseUrlNotifier.value = localhostBaseUrl;
        break;
      case DeviceTarget.custom:
        if (customIp != null && customIp.isNotEmpty) {
          baseUrlNotifier.value = customIp.startsWith('http') ? customIp : 'http://$customIp$defaultPath';
        }
        break;
    }
  }

  static void setCustomUrl(String url) {
    targetNotifier.value = DeviceTarget.custom;
    baseUrlNotifier.value = url.trim();
  }

  // Endpoints
  static String get testUrl => '$baseUrl/test.php';
  static String get produkUrl => '$baseUrl/produk.php';
  static String get transaksiUrl => '$baseUrl/transaksi.php';
  static String get dashboardUrl => '$baseUrl/dashboard.php';
}
