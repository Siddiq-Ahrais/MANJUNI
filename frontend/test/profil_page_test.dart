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
      'ProfilPage shows 0 registered products and 0 Orang for Pelanggan for new user',
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

    // Verify "Pelanggan Kasbon" is completely absent
    expect(find.text('Pelanggan Kasbon'), findsNothing);

    // Verify "Pelanggan" is present and starts at 0 Orang
    expect(find.text('Pelanggan'), findsNWidgets(2));
    expect(find.text('0 Orang'), findsOneWidget);

    // Verify "Produk Terdaftar" is present and starts at 0
    expect(find.text('Produk Terdaftar'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('ProfilPage dynamically updates when products and customers are added',
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

    // Initially 0 products and 0 Orang
    expect(find.text('0'), findsOneWidget);
    expect(find.text('0 Orang'), findsOneWidget);

    // Add a product via ApiService
    await ApiService.addProduct(
      name: 'Kopi Kapal Api',
      price: 3000,
      stock: 10,
      unit: 'pcs',
      category: 'Minuman',
    );
    await tester.pumpAndSettle();

    // Product count dynamically increments to 1
    expect(find.text('1'), findsOneWidget);

    // Add a customer via ApiService
    await ApiService.addCustomer(name: 'Pak Budi');
    await tester.pumpAndSettle();

    // Customer count dynamically increments to 1 Orang
    expect(find.text('1 Orang'), findsOneWidget);
  });
}
