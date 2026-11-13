import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/mobile_shell.dart';
import 'package:majunih/pages/dashboard_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
  });

  testWidgets('Toggle Analytics menampilkan statistik tanpa menghilangkan button-nya',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DashboardPage())),
    );
    await tester.pumpAndSettle();

    // Konten Overview tampil di awal
    expect(find.text('Total orders'), findsOneWidget);

    // Tap 'Analytics' -> konten statistik muncul, button toggle tetap ada
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle(const Duration(seconds: 6));

    expect(find.text('Penjualan vs Pembelian'), findsOneWidget);
    expect(find.text('Produk Terlaris'), findsOneWidget);
    expect(find.text('Total orders'), findsNothing);

    // Button toggle tidak ikut ter-hide
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);

    // Kembali ke Overview
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Total orders'), findsOneWidget);
    expect(find.text('Penjualan vs Pembelian'), findsNothing);
  });

  testWidgets('Membuka Analytics dari shell: navbar (Profil) tetap tampil',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MobileShell()));
    await tester.pumpAndSettle();

    // Navbar memuat ikon Profil sebelum Analytics dibuka
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Konten Analytics tampil in-place
    expect(find.text('Penjualan vs Pembelian'), findsOneWidget);

    // Navbar tidak hilang: ikon Profil tetap ada di bawah
    // (ikon receipt dihindari karena dipakai juga di kartu 'Transaksi' Analytics)
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
  });
}
