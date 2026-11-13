import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/analytics_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Gunakan penyimpanan in-memory agar test tidak menyentuh platform channel asli
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
  });

  testWidgets('AnalyticsPage renders stat cards and all diagram sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Kartu statistik
    expect(find.text('Penjualan'), findsWidgets);
    expect(find.text('Pembelian'), findsWidgets);
    expect(find.text('Laba Bersih'), findsOneWidget);
    expect(find.text('Transaksi'), findsWidgets);

    // Judul section diagram
    expect(find.text('Penjualan vs Pembelian'), findsOneWidget);
    expect(find.text('Tren Penjualan'), findsOneWidget);
    expect(find.text('Komposisi Pembelian'), findsOneWidget);
    expect(find.text('Produk Terlaris'), findsOneWidget);

    // Chip periode tren
    expect(find.text('7 Hari'), findsOneWidget);
    expect(find.text('30 Hari'), findsOneWidget);
    expect(find.text('6 Bulan'), findsOneWidget);
  });

  testWidgets('AnalyticsPage shows offline revenue from local transactions',
      (WidgetTester tester) async {
    // Catat transaksi offline -> revenue Rp6.000 harus muncul di kartu statistik
    await ApiService.addProduct(
      name: 'Kopi Kapal Api',
      price: 3000,
      stock: 10,
      unit: 'pcs',
      category: 'Minuman',
    );
    await ApiService.createTransaction(
      cartItems: [
        {'name': 'Kopi Kapal Api', 'qty': 2, 'price': 3000},
      ],
      itemsSummary: '2 Kopi Kapal Api',
      paymentMethod: 'Tunai',
      totalAmount: 6000,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));

    expect(find.text('Rp6.000'), findsWidgets);
  });

  testWidgets('Switching trend period chip rebuilds the chart section',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Scroll ke chip periode lalu tap '30 Hari' -> kartu tren tetap tampil
    await tester.ensureVisible(find.text('30 Hari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 Hari'));
    await tester.pumpAndSettle();

    expect(find.text('Tren Penjualan'), findsOneWidget);
    expect(find.textContaining('Periode 30 Hari'), findsOneWidget);
  });
}
