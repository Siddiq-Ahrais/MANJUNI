import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/dashboard_page.dart';
import 'package:majunih/pages/profil_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:majunih/services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    CartService.clear();
    NavigationService.selectedIndex.value = 0;
  });

  testWidgets('P2 & P4: DashboardPage header menu opens drawer, and profile taps link to Profile page (index 4)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: const Drawer(
            child: Text('Sidebar Drawer Terbuka'),
          ),
          body: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial state
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('Sidebar Drawer Terbuka'), findsNothing);

    // P2: Tap 3-line hamburger menu button
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Drawer is now open!
    expect(find.text('Sidebar Drawer Terbuka'), findsOneWidget);

    // Close drawer
    scaffoldKey.currentState?.closeDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Sidebar Drawer Terbuka'), findsNothing);

    // P4: Tap profile avatar/section in overview header
    expect(NavigationService.selectedIndex.value, 0);
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    // NavigationService has navigated to index 4 (ProfilPage)
    expect(NavigationService.selectedIndex.value, 4);
  });

  testWidgets('P3: ProfilPage allows editing store name and persists changes',
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

    // Default store name appears in header and profile card
    expect(find.text('Nama Toko Anda'), findsWidgets);
    expect(find.text('MJ'), findsOneWidget);

    // Tap pencil edit button
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Edit modal appears
    expect(find.text('Ubah Identitas Toko'), findsOneWidget);
    expect(find.text('Nama Toko'), findsOneWidget);

    // Enter new store name into first TextField
    final nameFieldFinder = find.byType(TextField).first;
    expect(nameFieldFinder, findsOneWidget);
    await tester.enterText(nameFieldFinder, 'Toko Berkah Mandiri');
    await tester.pumpAndSettle();

    // Tap Simpan
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Store name is now updated on the profile card and header
    expect(find.text('Toko Berkah Mandiri'), findsWidgets);
    // Initials should now be 'TB' (Toko Berkah)
    expect(find.text('TB'), findsOneWidget);

    // Verify it is saved in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('store_name'), 'Toko Berkah Mandiri');
  });
}
