import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:majunih/features/auth/screens/login_screen.dart';
import 'package:majunih/features/auth/screens/register_screen.dart';
import 'package:majunih/services/auth_service.dart';
import 'package:majunih/services/navigation_service.dart';
import 'package:majunih/shell.dart';

@Timeout(Duration(seconds: 30))
void main() {
  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.init();
    await AuthService.logout();
    NavigationService.selectedIndex.value = 0;
  });

  testWidgets('LoginScreen renders brand, inputs, and actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MANJUNI POS'), findsOneWidget);
    expect(find.text('Masuk ke Akun'), findsOneWidget);
    expect(find.text('Alamat Email'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Masuk Mode Offline / Tamu'), findsOneWidget);
    expect(find.text('Daftar Baru'), findsOneWidget);

    // Verify API bar and demo chips are removed
    expect(find.text('Ubah Host'), findsNothing);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Kasir'), findsNothing);
    expect(find.text('Partner'), findsNothing);

    // Enter text into email field
    await tester.enterText(find.byType(TextField).first, 'owner@manjuni.com');
    await tester.pumpAndSettle();

    expect(find.text('owner@manjuni.com'), findsOneWidget);
  });

  testWidgets('Login form validation triggers on empty submit',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders all required business and owner fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daftar Toko & Akun Baru'), findsOneWidget);
    expect(find.text('INFORMASI BISNIS / TOKO'), findsOneWidget);
    expect(find.text('Nama Toko / Usaha *'), findsOneWidget);
    expect(find.text('AKUN PEMILIK (OWNER)'), findsOneWidget);
    expect(find.text('Nama Lengkap Anda *'), findsOneWidget);
    expect(find.text('Email Login *'), findsOneWidget);
    expect(find.text('Kata Sandi (Minimal 8 Karakter) *'), findsOneWidget);
    expect(find.text('Konfirmasi Kata Sandi *'), findsOneWidget);
    expect(find.text('Daftarkan Toko & Akun'), findsOneWidget);

    // Test validation
    await tester.ensureVisible(find.text('Daftarkan Toko & Akun'));
    await tester.tap(find.text('Daftarkan Toko & Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Nama toko wajib diisi'), findsOneWidget);
    expect(find.text('Nama pemilik wajib diisi'), findsOneWidget);
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
  });

  testWidgets('AuthService guest login and session flow',
      (WidgetTester tester) async {
    expect(AuthService.isLoggedIn, isFalse);

    await AuthService.loginAsGuest(
      role: 'owner',
      storeName: 'Toko Manjuni Test',
      userName: 'Test Owner',
    );

    expect(AuthService.isLoggedIn, isTrue);
    expect(AuthService.currentUser?.name, 'Test Owner');
    expect(AuthService.currentUser?.business?.name, 'Toko Manjuni Test');
    expect(AuthService.authHeaders['Authorization'], isNotNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: MainShell(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MainShell renders
    expect(find.byType(MainShell), findsOneWidget);

    // Verify tapping profile header navigates to Profile page (index 4)
    expect(find.text('Hello, Test Owner!'), findsOneWidget);
    await tester.tap(find.text('Hello, Test Owner!'));
    await tester.pumpAndSettle();
    expect(NavigationService.selectedIndex.value, 4);

    // Logout
    await AuthService.logout();
    expect(AuthService.isLoggedIn, isFalse);
    expect(AuthService.currentUser, isNull);
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  bool autoUncompress = true;
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final List<int> kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];
