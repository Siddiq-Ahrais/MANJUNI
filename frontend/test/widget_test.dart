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
    ApiService.authStateNotifier.value = true;
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

  test('Full Offline Mode: Opens directly without password, supports PIN & 2 alphanumeric Security Names',
      () async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();

    // 1. Default mode is 100% offline & unlocked without password login
    expect(ApiService.offlineModeNotifier.value, isTrue);
    expect(ApiService.hasSecurityPin, isFalse);
    expect(ApiService.authStateNotifier.value, isTrue);

    // 2. Reject mismatched PIN confirmation
    final mismatchRes = await ApiService.setSecurityPin(
      pin: '123456',
      confirmPin: '654321',
      securityName1: 'Budi01',
      securityName2: 'Warung02',
    );
    expect(mismatchRes['success'], isFalse);

    // 3. Reject non-alphanumeric security names
    final invalidNameRes = await ApiService.setSecurityPin(
      pin: '123456',
      confirmPin: '123456',
      securityName1: 'Budi@01',
      securityName2: 'Warung02',
    );
    expect(invalidNameRes['success'], isFalse);

    // 4. Save valid PIN + 2 alphanumeric security names ("indah" & "laut")
    final saveRes = await ApiService.setSecurityPin(
      pin: '123456',
      confirmPin: '123456',
      securityName1: 'indah',
      securityName2: 'laut',
    );
    expect(saveRes['success'], isTrue);
    expect(ApiService.hasSecurityPin, isTrue);

    // 5. Simulate closing and reopening the app: PIN lock activates
    await ApiService.loadLocalData(force: true);
    expect(ApiService.authStateNotifier.value, isFalse);

    // Wrong PIN fails, right PIN unlocks
    expect(ApiService.verifySecurityPin('000000'), isFalse);
    expect(ApiService.verifySecurityPin('123456'), isTrue);
    expect(ApiService.authStateNotifier.value, isTrue);

    // 6. Change Security Names: requires current PIN + 1 last char of both current names ("h" & "t") & BOTH new names simultaneously
    final wrongPinNameRes = await ApiService.changeSecurityNames(
      currentPin: '000000',
      lastCharName1: 'h',
      lastCharName2: 't',
      newSecurityName1: 'Andi99',
      newSecurityName2: 'Toko99',
    );
    expect(wrongPinNameRes['success'], isFalse);

    final wrongLastCharRes = await ApiService.changeSecurityNames(
      currentPin: '123456',
      lastCharName1: 'i',
      lastCharName2: 't',
      newSecurityName1: 'Andi99',
      newSecurityName2: 'Toko99',
    );
    expect(wrongLastCharRes['success'], isFalse);

    final partialNameRes = await ApiService.changeSecurityNames(
      currentPin: '123456',
      lastCharName1: 'h',
      lastCharName2: 't',
      newSecurityName1: 'Andi99',
      newSecurityName2: '',
    );
    expect(partialNameRes['success'], isFalse);

    final validChangeNamesRes = await ApiService.changeSecurityNames(
      currentPin: '123456',
      lastCharName1: 'h',
      lastCharName2: 't',
      newSecurityName1: 'Andi99',
      newSecurityName2: 'Toko99',
    );
    expect(validChangeNamesRes['success'], isTrue);
    expect(ApiService.verifySecurityNames(name1: 'indah', name2: 'laut'), isFalse);
    expect(ApiService.verifySecurityNames(name1: 'Andi99', name2: 'Toko99'), isTrue);

    // 7. Clear All App Data resets everything to empty like a first-time user
    await ApiService.addProduct(name: 'Gula', price: 15000, stock: 5, unit: 'kg');
    expect((await ApiService.getProducts()).length, 1);
    await ApiService.clearAllAppData();
    expect((await ApiService.getProducts()).isEmpty, isTrue);
    expect((await ApiService.getTransactions()).isEmpty, isTrue);
    expect(ApiService.hasSecurityPin, isFalse);
  });
}
