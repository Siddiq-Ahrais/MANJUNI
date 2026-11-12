import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/transaksi_page.dart';
import 'package:majunih/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.resetAllData();
  });

  testWidgets('TransaksiPage for new user displays empty transactions with Rp0 omzet and 0 count',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransaksiPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Warung Maju Jaya'), findsOneWidget);

    // Verify Omzet Hari Ini is Rp0
    expect(find.text('Omzet Hari Ini'), findsOneWidget);
    expect(find.text('Rp0'), findsOneWidget);
    expect(find.text('Belum ada omzet'), findsOneWidget);

    // Verify Jumlah Transaksi is 0
    expect(find.text('Jumlah Transaksi'), findsOneWidget);
    expect(find.text('0 Transaksi'), findsWidgets);
    expect(find.text('User baru'), findsOneWidget);

    // Verify empty state card
    expect(find.text('Belum Ada Riwayat Transaksi'), findsOneWidget);
    expect(find.text('Mulai Belanja Produk'), findsOneWidget);
  });

  testWidgets('Recording transaction dynamically updates TransaksiPage omzet and list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransaksiPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Create a transaction
    await ApiService.createTransaction(
      cartItems: [
        {'name': 'Beras Ramos 5kg', 'price': 65000, 'qty': 1, 'unit': 'kemasan'},
      ],
      itemsSummary: 'Beras Ramos 5kg (1x)',
      paymentMethod: 'Tunai',
      totalAmount: 65000,
    );
    await tester.pumpAndSettle();

    // Omzet should now be Rp65.000
    expect(find.text('Rp65.000'), findsWidgets);
    expect(find.text('1 Transaksi'), findsWidgets);

    // Transaction item summary should be visible
    expect(find.text('Beras Ramos 5kg (1x)'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('Tersinkron'), findsOneWidget);

    // Tap transaction to open detail dialog
    await tester.tap(find.text('Beras Ramos 5kg (1x)'));
    await tester.pumpAndSettle();

    // Detail dialog should be open
    expect(find.text('Rincian Produk:'), findsOneWidget);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Close detail dialog
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Rincian Produk:'), findsNothing);
  });
}

