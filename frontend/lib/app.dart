import "package:flutter/material.dart";

import "mobile_shell.dart";
import "pages/login_page.dart";
import "services/api_service.dart";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MANJUNI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF164E2E),
          primary: const Color(0xFF164E2E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Gerbang otentikasi:
/// - Belum punya token (belum login / token kedaluwarsa) -> LoginPage
/// - Sudah login -> MobileShell
/// Status login bersifat reaktif via ApiService.authStateNotifier,
/// sehingga logout maupun 401 otomatis mengembalikan user ke halaman login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiService.authStateNotifier,
      builder: (context, isLoggedIn, _) {
        return isLoggedIn ? const MobileShell() : const LoginPage();
      },
    );
  }
}
