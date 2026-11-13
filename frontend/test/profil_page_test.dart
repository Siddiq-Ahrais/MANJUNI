import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/profil_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Gunakan penyimpanan in-memory agar test tidak menyentuh platform channel asli
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    CartService.clear();
  });

  testWidgets(
      'ProfilPage shows 0 registered products, 0 transactions, and Cadangkan Data (no Pelanggan/Info Toko)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Pelanggan & Info Toko are removed per P0
    expect(find.text('Pelanggan'), findsNothing);
    expect(find.text('Info Toko'), findsNothing);

    // Verify Produk Terdaftar, Total Transaksi, and Cadangkan Data are present
    expect(find.text('Produk Terdaftar'), findsOneWidget);
    expect(find.text('Total Transaksi'), findsOneWidget);
    expect(find.text('Cadangkan Data'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('ProfilPage dynamically updates and exports transaction CSV via Cadangkan Data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Add a product and create a transaction
    await ApiService.addProduct(
      name: 'Kopi Kapal Api',
      price: 3000,
      stock: 10,
      unit: 'pcs',
      category: 'Minuman',
    );
    await ApiService.createTransaction(
      cartItems: [
        CartItem(name: 'Kopi Kapal Api', price: 3000, unit: 'pcs', maxStock: 10, qty: 2),
      ],
      itemsSummary: 'Kopi Kapal Api (2x)',
      paymentMethod: 'Tunai',
      totalAmount: 6000,
    );
    await tester.pumpAndSettle();

    // Both counts dynamically increment to 1
    expect(find.text('1'), findsNWidgets(2));

    // Open Cadangkan Data export dialog
    await tester.tap(find.text('Cadangkan Data'));
    await tester.pumpAndSettle();

    expect(find.text('Cadangkan Data Transaksi'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Perminggu'), findsOneWidget);
    expect(find.text('Bulan'), findsOneWidget);
    expect(find.text('Tahun'), findsOneWidget);
    expect(find.textContaining('sep=,'), findsOneWidget);
    expect(find.textContaining('id_transaksi,waktu_transaksi,jenis_pembayaran'), findsOneWidget);
    expect(find.textContaining('3000,6000'), findsOneWidget);

    // Mock Android file_export channel in case test runs on Android/desktop
    String? savedFileName;
    const channel = MethodChannel('com.example.majunih/file_export');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveCsvToDownloads') {
        final args = call.arguments as Map;
        savedFileName = args['fileName']?.toString();
        return 'Download/${args['fileName']}';
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // Switch export period to Perminggu and verify Simpan CSV uses period in filename
    await tester.tap(find.text('Perminggu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(Perminggu) siap diekspor'), findsOneWidget);

    // Tap Simpan CSV and verify confirmation SnackBar appears
    expect(find.text('Simpan CSV'), findsOneWidget);
    await tester.tap(find.text('Simpan CSV'));
    await tester.pumpAndSettle();

    expect(savedFileName, startsWith('manjuni_transaksi_minggu_'));
    expect(find.textContaining('Backup CSV tersimpan di:'), findsOneWidget);
  });

  test('filterTransactionsByPeriod filters weekly, monthly, yearly, and all', () {
    final ref = DateTime(2026, 11, 20, 12, 0);
    final list = <Map<String, dynamic>>[
      {'id': 'TRX-WEEK', 'date': '2026-11-18'},
      {'id': 'TRX-MONTH', 'date': '2026-11-02'},
      {'id': 'TRX-YEAR', 'date': '2026-08-10'},
      {'id': 'TRX-OLD', 'date': '2025-12-30'},
    ];

    expect(
      ApiService.filterTransactionsByPeriod(list, 'minggu', referenceDate: ref)
          .map((e) => e['id'])
          .toList(),
      ['TRX-WEEK'],
    );
    expect(
      ApiService.filterTransactionsByPeriod(list, 'bulan', referenceDate: ref)
          .map((e) => e['id'])
          .toList(),
      ['TRX-WEEK', 'TRX-MONTH'],
    );
    expect(
      ApiService.filterTransactionsByPeriod(list, 'tahun', referenceDate: ref)
          .map((e) => e['id'])
          .toList(),
      ['TRX-WEEK', 'TRX-MONTH', 'TRX-YEAR'],
    );
    expect(
      ApiService.filterTransactionsByPeriod(list, 'semua', referenceDate: ref)
          .length,
      4,
    );
  });
}
