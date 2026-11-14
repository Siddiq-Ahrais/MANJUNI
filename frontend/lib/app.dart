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
/// - Belum punya token / PIN belum dibuka -> LoginPage
/// - Sudah login / terbuka -> MobileShell
/// Status login bersifat reaktif via ApiService.authStateNotifier,
/// dan mengunci ulang otomatis saat aplikasi ke background jika PIN aktif.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        ApiService.hasSecurityPin &&
        !ApiService.isPickingExternalFile) {
      ApiService.lockApp();
    }
  }

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
