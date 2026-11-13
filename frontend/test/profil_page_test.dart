import 'package:flutter/material.dart';
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
    expect(find.textContaining('id_transaksi,waktu_transaksi,jenis_pembayaran'), findsOneWidget);
    expect(find.textContaining('3000,6000'), findsOneWidget);
  });
}
