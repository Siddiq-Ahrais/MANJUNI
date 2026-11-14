import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majunih/app.dart';
import 'package:majunih/pages/login_page.dart';
import 'package:majunih/pages/profil_page.dart';
import 'package:majunih/pages/transaksi_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/security_crypto.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiService.isPickingExternalFile = false;
    ApiService.resetAllData();
    await ApiService.loadLocalData(force: true);
  });

  group('SecurityCrypto (SHA-256 & PBKDF2)', () {
    test('cocok dengan vektor uji NIST SHA-256', () {
      expect(
        SecurityCrypto.sha256Hex(utf8.encode('')),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        SecurityCrypto.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        SecurityCrypto.sha256Hex(
          utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
          ),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('PBKDF2 menghasilkan salt acak unik & memverifikasi rahasia dengan benar', () {
      final hash1 = SecurityCrypto.hashSecret('4829');
      final hash2 = SecurityCrypto.hashSecret('4829');

      expect(SecurityCrypto.isHashed(hash1), isTrue);
      expect(hash1, isNot(equals(hash2)));
      expect(hash1, isNot(contains('4829')));
      expect(SecurityCrypto.verifySecret('4829', hash1), isTrue);
      expect(SecurityCrypto.verifySecret('4829', hash2), isTrue);
      expect(SecurityCrypto.verifySecret('0000', hash1), isFalse);
    });
  });

  group('Hardening PIN, Hashing & Rate Limiting', () {
    test('kredensial tersimpan dalam bentuk hash bersalt, bukan plaintext', () async {
      final res = await ApiService.setSecurityPin(
        pin: '4829',
        confirmPin: '4829',
        securityName1: 'Budi1',
        securityName2: 'Santoso2',
      );
      expect(res['success'], isTrue);

      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('mj_security_pin_v2') ?? '';
      final storedN1 = prefs.getString('mj_security_name_1_v2') ?? '';
      final storedN2 = prefs.getString('mj_security_name_2_v2') ?? '';
      final storedL1 = prefs.getString('mj_security_last_char_1_v2') ?? '';
      final storedL2 = prefs.getString('mj_security_last_char_2_v2') ?? '';

      expect(SecurityCrypto.isHashed(storedPin), isTrue);
      expect(SecurityCrypto.isHashed(storedN1), isTrue);
      expect(SecurityCrypto.isHashed(storedN2), isTrue);
      expect(SecurityCrypto.isHashed(storedL1), isTrue);
      expect(SecurityCrypto.isHashed(storedL2), isTrue);

      expect(storedPin, isNot(contains('4829')));
      expect(storedN1.toLowerCase(), isNot(contains('budi1')));
      expect(storedN2.toLowerCase(), isNot(contains('santoso2')));

      expect(ApiService.verifySecurityPin('4829'), isTrue);
      expect(
        ApiService.verifySecurityNames(name1: 'budi1', name2: 'SANTOSO2'),
        isTrue,
      );
      expect(
        ApiService.verifySecurityNamesLastChar(lastChar1: '1', lastChar2: '2'),
        isTrue,
      );
    });

    test('migrasi otomatis kredensial plaintext versi lama saat loadLocalData', () async {
      SharedPreferences.setMockInitialValues({
        'mj_security_pin_v2': '9876',
        'mj_security_name_1_v2': 'Mawar',
        'mj_security_name_2_v2': 'Melati',
        'mj_users_v2': jsonEncode([
          {'email': 'owner@toko.id', 'name': 'Owner', 'password': 'rahasia123'},
        ]),
      });

      await ApiService.loadLocalData(force: true);
      final prefs = await SharedPreferences.getInstance();
      final migratedPin = prefs.getString('mj_security_pin_v2') ?? '';
      final migratedN1 = prefs.getString('mj_security_name_1_v2') ?? '';
      final migratedUsers = prefs.getString('mj_users_v2') ?? '';

      expect(SecurityCrypto.isHashed(migratedPin), isTrue);
      expect(SecurityCrypto.isHashed(migratedN1), isTrue);
      expect(migratedPin, isNot(contains('9876')));
      expect(migratedUsers, isNot(contains('rahasia123')));

      expect(ApiService.verifySecurityPin('9876'), isTrue);
      expect(
        ApiService.verifySecurityNamesLastChar(lastChar1: 'r', lastChar2: 'i'),
        isTrue,
      );

      final loginOk = await ApiService.login(
        email: 'owner@toko.id',
        password: 'rahasia123',
      );
      expect(loginOk['success'], isTrue);
    });

    test('menolak PIN di bawah 4 digit atau non-angka', () async {
      final shortRes = await ApiService.setSecurityPin(
        pin: '123',
        confirmPin: '123',
        securityName1: 'Alfa1',
        securityName2: 'Beta2',
      );
      expect(shortRes['success'], isFalse);
      expect(shortRes['message'].toString(), contains('4 digit'));

      final alphaRes = await ApiService.setSecurityPin(
        pin: '12ab',
        confirmPin: '12ab',
        securityName1: 'Alfa1',
        securityName2: 'Beta2',
      );
      expect(alphaRes['success'], isFalse);

      await ApiService.setSecurityPin(
        pin: '1234',
        confirmPin: '1234',
        securityName1: 'Alfa1',
        securityName2: 'Beta2',
      );
      final shortChange = await ApiService.changeSecurityPin(
        oldPin: '1234',
        securityName1: 'Alfa1',
        securityName2: 'Beta2',
        newPin: '99',
        confirmNewPin: '99',
      );
      expect(shortChange['success'], isFalse);

      final shortReset = await ApiService.unlockWithSecurityNames(
        name1: 'Alfa1',
        name2: 'Beta2',
        newPin: '777',
        confirmPin: '777',
      );
      expect(shortReset['success'], isFalse);

      // Unlock tanpa mengganti PIN tetap diizinkan
      final unlockOnly = await ApiService.unlockWithSecurityNames(
        name1: 'Alfa1',
        name2: 'Beta2',
      );
      expect(unlockOnly['success'], isTrue);
    });

    test('jeda 30 detik aktif setelah 5 kali salah PIN dan Nama Keamanan', () async {
      await ApiService.setSecurityPin(
        pin: '4321',
        confirmPin: '4321',
        securityName1: 'Alfa1',
        securityName2: 'Beta2',
      );

      for (var i = 0; i < 4; i++) {
        final r = await ApiService.verifySecurityPinDetailed('0000');
        expect(r['success'], isFalse);
        expect(r['lockedOut'], isFalse);
      }

      final fifth = await ApiService.verifySecurityPinDetailed('0000');
      expect(fifth['success'], isFalse);
      expect(fifth['lockedOut'], isTrue);
      expect(fifth['remainingSeconds'], greaterThan(0));
      expect(fifth['remainingSeconds'], lessThanOrEqualTo(30));

      // PIN yang benar sekalipun ditolak selama masa jeda
      final blockedCorrect = await ApiService.verifySecurityPinDetailed('4321');
      expect(blockedCorrect['success'], isFalse);
      expect(blockedCorrect['lockedOut'], isTrue);

      for (var i = 0; i < 5; i++) {
        await ApiService.verifySecurityNamesDetailed(
          name1: 'Salah1',
          name2: 'Salah2',
        );
      }
      final recoveryBlocked = await ApiService.verifySecurityNamesDetailed(
        name1: 'Alfa1',
        name2: 'Beta2',
      );
      expect(recoveryBlocked['success'], isFalse);
      expect(recoveryBlocked['lockedOut'], isTrue);
    });
  });

  group('Sanitasi CSV Export', () {
    test('mencegah CSV formula injection pada awalan =, +, -, @, tab, CR', () {
      final csv = ApiService.buildTransactionsExportCsv([
        {
          'id': '=CMD|calc',
          'date': '2026-11-14',
          'time': '+12:00',
          'method': '@SUM(1,1)',
          'amount': 15000,
          'cartItems': [
            {'name': '-2+3', 'qty': 1, 'price': 5000},
            {'name': '\t=A1', 'qty': 1, 'price': 5000},
            {'name': '  =HYPERLINK("x")', 'qty': 1, 'price': 5000},
            {'name': 'Es Teh Manis', 'qty': 1, 'price': 5000},
          ],
        },
      ]);

      expect(csv, contains("\"'=CMD|calc\""));
      expect(csv, contains("\"'@SUM(1,1)\""));
      expect(csv, contains("\"'-2+3\""));
      expect(csv, contains("\"'\t=A1\""));
      expect(csv, contains("\"'  =HYPERLINK(\"\"x\"\")\""));
      expect(csv, contains('"Es Teh Manis"'));
    });
  });

  group('Auto-Lock & Proteksi PIN Aksi Destruktif (Widget)', () {
    testWidgets('AuthGate mengunci ulang saat AppLifecycleState.paused kecuali pick file', (
      tester,
    ) async {
      await ApiService.setSecurityPin(
        pin: '2468',
        confirmPin: '2468',
        securityName1: 'Langit1',
        securityName2: 'Bumi2',
      );
      ApiService.authStateNotifier.value = true;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Saat membuka pemilih gambar eksternal, transisi ke paused tidak mengunci sesi
      ApiService.isPickingExternalFile = true;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(ApiService.authStateNotifier.value, isTrue);

      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();

      // Paused normal mengunci sesi sehingga saat resumed langsung tampil LoginPage
      ApiService.isPickingExternalFile = false;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(ApiService.authStateNotifier.value, isFalse);

      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Reset Riwayat di TransaksiPage meminta PIN jika PIN aktif', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'mj_transactions_v2': jsonEncode([
          {
            'id': 'TRX-1',
            'amount': 12000,
            'method': 'Tunai',
            'date': '2026-11-14',
            'time': '10:00',
            'items': 'Kopi (1x)',
          },
        ]),
      });
      await ApiService.loadLocalData(force: true);
      await ApiService.setSecurityPin(
        pin: '5678',
        confirmPin: '5678',
        securityName1: 'Pagi1',
        securityName2: 'Sore2',
      );
      ApiService.authStateNotifier.value = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TransaksiPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset'));
      await tester.pumpAndSettle();

      // Dialog PIN muncul
      expect(find.byKey(const Key('confirm_action_pin_field')), findsOneWidget);

      // PIN salah tidak mereset data
      await tester.enterText(
        find.byKey(const Key('confirm_action_pin_field')),
        '1111',
      );
      await tester.tap(find.byKey(const Key('confirm_action_pin_submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PIN keamanan salah'), findsOneWidget);
      expect(await ApiService.getTransactions(), hasLength(1));

      // PIN benar mengeksekusi reset
      await tester.enterText(
        find.byKey(const Key('confirm_action_pin_field')),
        '5678',
      );
      await tester.tap(find.byKey(const Key('confirm_action_pin_submit')));
      await tester.pumpAndSettle();
      expect(await ApiService.getTransactions(), isEmpty);
    });

    testWidgets('Kosongkan Data Aplikasi di ProfilPage meminta PIN jika PIN aktif', (
      tester,
    ) async {
      await ApiService.addProduct(
        name: 'Produk Uji',
        price: 7000,
        stock: 10,
        unit: 'pcs',
        costPrice: 5000,
      );
      await ApiService.setSecurityPin(
        pin: '5678',
        confirmPin: '5678',
        securityName1: 'Pagi1',
        securityName2: 'Sore2',
      );
      ApiService.authStateNotifier.value = true;

      await tester.pumpWidget(const MaterialApp(home: ProfilPage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Kosongkan Data Aplikasi'));
      await tester.tap(find.text('Kosongkan Data Aplikasi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ya, Kosongkan Semua'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_action_pin_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('confirm_action_pin_field')),
        '0000',
      );
      await tester.tap(find.byKey(const Key('confirm_action_pin_submit')));
      await tester.pumpAndSettle();
      expect(await ApiService.getProducts(), hasLength(1));

      await tester.enterText(
        find.byKey(const Key('confirm_action_pin_field')),
        '5678',
      );
      await tester.tap(find.byKey(const Key('confirm_action_pin_submit')));
      await tester.pumpAndSettle();
      expect(await ApiService.getProducts(), isEmpty);
    });
  });
}
