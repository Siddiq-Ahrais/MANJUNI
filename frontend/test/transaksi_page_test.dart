import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/transaksi_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Gunakan penyimpanan in-memory agar test tidak menyentuh platform channel asli
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('Detail produk per transaksi tetap tersimpan dan tampil lengkap saat diklik',
      (WidgetTester tester) async {
    await ApiService.createTransaction(
      cartItems: [
        CartItem(
          productId: 101,
          name: 'Minyak Goreng 1L',
          price: 18000,
          costPrice: 15000,
          unit: 'botol',
          qty: 2,
        ),
        CartItem(
          productId: 102,
          name: 'Gula Pasir',
          price: 16000,
          costPrice: 13500,
          unit: 'kg',
          qty: 3,
        ),
      ],
      itemsSummary: 'Minyak Goreng 1L (2 botol), Gula Pasir (3 kg)',
      paymentMethod: 'QRIS',
      totalAmount: 84000,
    );

    // Simulasikan reload dari SharedPreferences
    await ApiService.loadLocalData(force: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: TransaksiPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minyak Goreng 1L (2 botol), Gula Pasir (3 kg)'));
    await tester.pumpAndSettle();

    expect(find.text('Rincian Produk:'), findsOneWidget);
    expect(find.text('Minyak Goreng 1L'), findsOneWidget);
    expect(find.text('2 botol × Rp18.000'), findsOneWidget);
    expect(find.text('Rp36.000'), findsOneWidget);
    expect(find.text('Gula Pasir'), findsOneWidget);
    expect(find.text('3 kg × Rp16.000'), findsOneWidget);
    expect(find.text('Rp48.000'), findsOneWidget);
    expect(find.text('Rp84.000'), findsWidgets);
  });

  testWidgets('Tombol Reset mengosongkan riwayat transaksi dan bertahan setelah reload',
      (WidgetTester tester) async {
    await ApiService.createTransaction(
      cartItems: [
        CartItem(
          productId: 201,
          name: 'Kopi Susu',
          price: 12000,
          costPrice: 8000,
          unit: 'gelas',
          qty: 2,
        ),
      ],
      itemsSummary: 'Kopi Susu (2 gelas)',
      paymentMethod: 'Tunai',
      totalAmount: 24000,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TransaksiPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kopi Susu (2 gelas)'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Riwayat'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Kopi Susu (2 gelas)'), findsNothing);
    expect(find.text('Belum Ada Riwayat Transaksi'), findsOneWidget);
    expect(find.text('0 Transaksi'), findsWidgets);
    expect(find.text('Rp0'), findsWidgets);

    // Pastikan tetap kosong setelah dimuat ulang dari SharedPreferences
    await ApiService.loadLocalData(force: true);
    final persisted = await ApiService.getTransactions();
    expect(persisted, isEmpty);
  });
}

