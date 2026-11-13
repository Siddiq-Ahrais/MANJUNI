import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/app.dart';
import 'package:majunih/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Gunakan penyimpanan in-memory agar test tidak menyentuh platform channel asli
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
  });

  testWidgets('App renders MobileShell with bottom navigation and navigates to Produk',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify initial active tab label is Overview
    expect(find.text('Overview'), findsWidgets);

    // Verify navigation icons exist
    expect(find.byIcon(Icons.storefront), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

    // Tap 'Produk' tab icon in bottom navigation
    await tester.tap(find.byIcon(Icons.storefront));
    await tester.pumpAndSettle();

    // Produk tab is now active and label is visible
    expect(find.text('Produk'), findsWidgets);

    // Verify Produk page is loaded and active
    expect(find.text('Daftar Produk'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Tambah Produk'), findsOneWidget);

    // Verify FloatingActionButton is removed in favor of single button under Daftar Produk
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
