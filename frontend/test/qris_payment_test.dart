import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/keranjang_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:majunih/widgets/qris_payment_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    CartService.clear();
  });

  testWidgets('QrisPaymentDialog renders generate tab with QR Code, invoice and amount',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool paymentConfirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                QrisPaymentDialog.show(
                  context,
                  totalAmount: 75000,
                  customerName: 'Budi Santoso',
                  itemsSummary: 'Beras 5kg (1 kemasan)',
                  onConfirmPayment: ({
                    required String barcodeOrQr,
                    required String methodDetail,
                  }) async {
                    paymentConfirmed = true;
                    return true;
                  },
                );
              },
              child: const Text('Buka QRIS'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Buka QRIS'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dialog header & amount
    expect(find.text('Pembayaran QRIS & Barcode'), findsOneWidget);
    expect(find.text('Total Tagihan: Rp75.000'), findsOneWidget);

    // Verify 2 tabs are visible
    expect(find.text('Tampilkan QRIS / Barcode'), findsOneWidget);
    expect(find.text('Pindai Barcode Pelanggan'), findsOneWidget);

    // Verify QR Code 2D & Barcode 1D choice chips
    expect(find.text('QR Code (2D)'), findsOneWidget);
    expect(find.text('Barcode (1D)'), findsOneWidget);

    // Verify invoice and total nominal display
    expect(find.text('Nominal Bayar'), findsOneWidget);
    expect(find.text('Rp75.000'), findsWidgets);
    expect(find.text('No. Invoice'), findsOneWidget);

    // Toggle to 1D Barcode
    await tester.tap(find.text('Barcode (1D)'));
    await tester.pump(const Duration(milliseconds: 200));

    // Tap "Simulasi Bayar" to verify auto payment trigger
    expect(find.text('Simulasi Bayar'), findsOneWidget);
    await tester.tap(find.text('Simulasi Bayar'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    // Pump past the 900ms close timer
    await tester.pump(const Duration(milliseconds: 1000));

    expect(paymentConfirmed, isTrue);
  });

  testWidgets('QrisPaymentDialog scan mode allows barcode scanning and e-wallet preset testing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? capturedBarcode;
    String? capturedMethod;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                QrisPaymentDialog.show(
                  context,
                  totalAmount: 120000,
                  customerName: 'Siti Rahma',
                  itemsSummary: 'Minyak 2L (2 pcs)',
                  onConfirmPayment: ({
                    required String barcodeOrQr,
                    required String methodDetail,
                  }) async {
                    capturedBarcode = barcodeOrQr;
                    capturedMethod = methodDetail;
                    return true;
                  },
                );
              },
              child: const Text('Buka QRIS Scanner'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka QRIS Scanner'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Scan Tab
    await tester.tap(find.text('Pindai Barcode Pelanggan'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify camera controls and instructions
    expect(find.text('KAMERA AKTIF'), findsOneWidget);
    expect(find.text('Arahkan kamera ke barcode / QR pelanggan'), findsOneWidget);

    // Verify preset chips are present
    expect(find.text('GoPay CPM'), findsOneWidget);
    expect(find.text('DANA QRIS'), findsOneWidget);
    expect(find.text('ShopeePay'), findsOneWidget);
    expect(find.text('OVO Cash'), findsOneWidget);

    // Tap GoPay CPM preset
    await tester.tap(find.text('GoPay CPM'));
    await tester.pump(const Duration(milliseconds: 200));

    // Status updates to scanned
    expect(find.text('KODE TERDETEKSI'), findsOneWidget);
    expect(find.textContaining('GoPay Terdeteksi'), findsOneWidget);

    // Confirm payment button is now active
    expect(find.text('Proses Pembayaran (Rp120.000)'), findsOneWidget);
    await tester.tap(find.text('Proses Pembayaran (Rp120.000)'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    // Pump past the 900ms close timer
    await tester.pump(const Duration(milliseconds: 1000));

    expect(capturedBarcode, contains('9360081284910248'));
    expect(capturedMethod, contains('GoPay'));
  });

  testWidgets('KeranjangPage QRIS option records transaction as QRIS on Simpan without opening payment dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: KeranjangPage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Add item to cart
    CartService.addItem('Kopi Robusta 250g', 35000, 'bungkus');
    await tester.pump(const Duration(milliseconds: 200));

    // Select QRIS recording option (index 1)
    await tester.tap(find.text('QRIS'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify no QRIS payment banner/scanner is shown and Simpan button is ready
    expect(find.text('Metode Pencatatan'), findsOneWidget);
    expect(find.text('Dua Metode Pembayaran QRIS Tersedia:'), findsNothing);
    expect(find.text('Buka Layar QRIS & Scanner'), findsNothing);
    expect(find.text('Buka Scanner'), findsNothing);
    expect(find.text('Simpan'), findsOneWidget);

    // Tap Simpan directly records transaction as QRIS
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi Tersimpan!'), findsOneWidget);
    expect(find.text('Total: Rp35.000 (QRIS)'), findsOneWidget);
    expect(find.text('Pembayaran QRIS & Barcode'), findsNothing);
  });
}
