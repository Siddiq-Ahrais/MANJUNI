# MANJUNI – Manajemen UMKM Terkini

**MANJUNI** adalah aplikasi kasir (*Point of Sale*), pengelolaan inventori produk, perhitungan HPP & laba rugi, serta pencatatan transaksi UMKM berbasis **Flutter** yang dirancang untuk berjalan **100% offline langsung di perangkat pengguna**.

Seluruh fitur utama—mulai dari manajemen katalog & stok produk, transaksi kasir, analitik penjualan, penguncian keamanan PIN, hingga ekspor laporan CSV—beroperasi sepenuhnya secara lokal **tanpa koneksi internet, tanpa bergantung pada server online, bebas iklan, dan tanpa paywall**.

---

## Identitas Kompetisi & Karya

| Atribut | Keterangan |
| :--- | :--- |
| **Kategori Kompetisi** | Local MSME & Creative Economy |
| **Judul Karya** | MANJUNI – Manajemen UMKM Terkini |
| **Institusi / Universitas** | Universitas Indraprasta PGRI \| Universitas Bina Sarana Informatika |
| **Fakultas / Departemen** | Teknik Informatika \| Teknik Informasi |
| **Nama Tim** | Bebas Kata Ferdi |
| **Ketua Tim / Penulis Utama** | Ahmad Raisul Siddiq |
| **Informasi Kontak** | 089628836281 / raisulsiddiq1009@gmail.com |

---

## Anggota Tim & Jobdesk

| No. & Peran | Nama Lengkap | Nomor Induk Mahasiswa (NIM) |
| :--- | :--- | :--- |
| Anggota 1 – Project Manager, Backend Dev, QA Engineer, Frontend Dev | **Ahmad Raisul Siddiq** | `202443500970` |
| Anggota 2 – UI/UX, QA Engineer | **Azka Ezzikra** | `202543500865` |
| Anggota 3 – Frontend Dev, UI/UX, QA Engineer | **Muhamad Ferdi** | `17231160` |
| Anggota 4 – Frontend Dev, Backend Dev, QA Engineer | **Ahmad Zani Syechkar** | `202443502077` |

### Rincian Pembagian Jobdesk

- **Ahmad Raisul Siddiq** (*Project Manager, Backend Dev, QA Engineer, Frontend Dev*)
  - Mengoordinasikan perencanaan fitur, prioritas pengembangan, manajemen rilis, dan alur kerja tim hingga versi rilis stabil.
  - Merancang serta mengembangkan layanan logika bisnis lokal/offline (`ApiService`, `SecurityCrypto`), mekanisme penyimpanan persisten (`SharedPreferences`), serta berkontribusi pada implementasi antarmuka Frontend dan pengujian kualitas (QA).
- **Azka Ezzikra** (*UI/UX, QA Engineer*)
  - Merancang pengalaman pengguna (*user experience*) dan tata letak antarmuka (*user interface*) agar ramah bagi pelaku UMKM.
  - Melakukan pengujian QA fungsional, validasi alur penggunaan tiap halaman, serta verifikasi konsistensi tampilan dan interaksi aplikasi.
- **Muhamad Ferdi** (*Frontend Dev, UI/UX, QA Engineer*)
  - Mengimplementasikan komponen antarmuka Flutter (navigasi tab, form produk, keranjang, transaksi, dashboard/analytics, serta penyelarasan UI/UX) agar responsif dan mudah dioperasikan.
  - Melakukan penyempurnaan visual UI/UX serta pengujian QA pada alur tampilan dan interaksi pengguna.
- **Ahmad Zani Syechkar** (*Frontend Dev, Backend Dev, QA Engineer*)
  - Mengembangkan fitur Frontend Flutter sekaligus layanan logika/penyimpanan data aplikasi dan integrasi native perangkat (`MethodChannel` Android/file export).
  - Melaksanakan pengujian QA (termasuk pengujian widget, alur bisnis, dan keamanan aplikasi).

---

## Arsitektur 100% Offline

Aplikasi MANJUNI dibangun dengan prinsip **100% Offline / Local-First** tanpa komunikasi jaringan ke server eksternal:

- **Mode Offline Terkunci (`ApiService`)**: `ApiService.offlineModeNotifier` selalu bernilai `true` dan `isConnectedNotifier` bernilai `false`, sehingga seluruh operasi baca/tulis produk, keranjang, transaksi, profil toko, dan keamanan berjalan murni di perangkat.
- **Tanpa Izin Internet di Android (`AndroidManifest.xml`)**: Aplikasi Android (`com.example.majunih`) **tidak mendeklarasikan `android.permission.INTERNET`**, serta menetapkan `android:allowBackup="false"` dan `android:usesCleartextTraffic="false"`.
- **Penyimpanan Lokal Persisten (`SharedPreferences` `_v2`)**:
  - Menggunakan skema key bersih berakhiran `_v2` (`mj_products_v2`, `mj_transactions_v2`, `mj_customers_v2`, `mj_users_v2`, `mj_deleted_products_v2`, `mj_cart_v2`) dan otomatis membersihkan key legacy `_v1` saat inisialisasi `loadLocalData()`.
  - Menyimpan identitas toko (`store_name`, `store_category`) serta status keamanan PIN, nama keamanan, dan status rate-limiting (`mj_security_*_v2`, `mj_pin_*_v2`, `mj_recovery_*_v2`).
- **Akses File Perangkat Secara Lokal (`MethodChannel`)**:
  - Menggunakan `MethodChannel('com.example.majunih/file_export')` pada `MainActivity.kt` (Android) dan `OpenFileDialog` (Windows) untuk memilih foto produk langsung dari perangkat serta menyimpan file ekspor CSV langsung ke folder `Download` perangkat tanpa layanan cloud.
- **Catatan Direktori `backend/`**: Folder [`backend/`](./backend) di repositori merupakan arsip prototipe awal berbasis Laravel dari tahap perencanaan terdahulu dan **tidak digunakan** oleh aplikasi aktif MANJUNI di [`frontend/`](./frontend) yang berjalan 100% offline.

---

## Fitur Utama & Update Terakhir

### 1. Akses Masuk & Keamanan Lokal (`LoginPage`, `AuthGate`, `SecurityCrypto`)
- **Masuk Tanpa Akun Online**: Tidak menggunakan login email/password server. Jika PIN tidak diaktifkan, pengguna cukup menekan tombol **Masuk ke Aplikasi** untuk langsung menggunakan aplikasi. Jika PIN aktif, aplikasi menampilkan gerbang verifikasi PIN beserta opsi **Lupa Password? Buka dengan Nama Keamanan**.
- **Kriptografi Lokal Pure-Dart (`SecurityCrypto`)**:
  - Hashing PIN dan 2 Nama Keamanan memakai **PBKDF2-HMAC-SHA256** (`5.000` iterasi, salt acak 16-byte dari `Random.secure()`, digest 32-byte, format `pbkdf2_sha256$<iter>$<salt_hex>$<hash_hex>`) dengan perbandingan *constant-time*.
  - Kredensial plaintext lama otomatis dimigrasikan ke hash PBKDF2 saat aplikasi memuat data awal.
- **Rate Limiting & Cooldown Persisten**: Maksimal `5` kali percobaan salah pada verifikasi PIN maupun pemulihan Nama Keamanan akan mengaktifkan masa tunggu `30 detik` yang tetap bertahan meski aplikasi ditutup dan dibuka kembali.
- **Auto-Lock Otomatis (`AuthGate`)**: Aplikasi otomatis mengunci kembali (`ApiService.lockApp()`) ketika berpindah ke latar belakang (`AppLifecycleState.paused`) saat PIN aktif, dengan pengecualian aman agar tidak terkunci saat pengguna sedang memilih foto/file eksternal (`isPickingExternalFile`).
- **Manajemen PIN & Nama Keamanan di Profil**:
  - **Atur PIN Keamanan**: Opsional, minimal `4` digit angka disertai `2` Nama Keamanan alfanumerik (huruf & angka) sebagai kunci pemulihan, lengkap dengan banner peringatan bahwa PIN tidak dapat dilihat/di-recovery kembali selain melalui kedua Nama Keamanan.
  - **Ganti PIN & Nonaktifkan PIN**: Membutuhkan verifikasi PIN lama serta kedua Nama Keamanan.
  - **Ganti Nama Keamanan**: Wajib mengganti kedua Nama Keamanan secara serentak dengan memverifikasi PIN saat ini serta **1 karakter terakhir** dari masing-masing Nama Keamanan 1 dan Nama Keamanan 2 saat ini.
- **Konfirmasi PIN pada Aksi Destruktif (`confirmSecurityPinForAction`)**: Melindungi aksi **Reset** riwayat transaksi di halaman Transaksi dan **Kosongkan Data Aplikasi** di halaman Profil saat PIN keamanan aktif.

### 2. Dashboard Overview & Analytics (`DashboardPage`, `AnalyticsView`)
- **Navigasi 5 Tab Utama (`MobileShell`)**: `Overview`, `Produk`, `Keranjang` (dilengkapi badge jumlah item real-time dari `CartService.totalCount`), `Transaksi`, dan `Profil`.
- **Toggle In-Place `Overview` / `Analytics`**: Berpindah antara ringkasan cepat dan analitik mendalam dalam tab yang sama, serta mengetuk kartu header toko untuk langsung membuka tab `Profil`.
- **Mode `Overview`**:
  - Filter rentang waktu `Today`, `This week`, `This month`, dan `All time`.
  - Kartu ringkasan `Total orders` dan `Total revenue` (`Rp`).
  - Daftar peringkat **Top Seller (Produk Terlaris)** dengan badge `#1 Top Seller` dan pintasan `View all` menuju tampilan `Analytics`.
  - Daftar **Recent activity** dengan pintasan `View all` menuju tab `Transaksi`.
- **Mode `Analytics` (`AnalyticsView`)**:
  - 4 kartu ringkasan: `Penjualan`, `Pembelian`, `Laba Bersih`, dan `Transaksi`.
  - Grafik perbandingan **Penjualan vs Pembelian** (`_CompareBarPainter`) yang menampilkan rincian `HPP`, `Laba Kotor`, `Margin Kotor (%)`, dan `Markup (vs HPP) (%)`.
  - Grafik tren jumlah produk terjual interaktif (`7 Hari`, `30 Hari`, `6 Bulan`) dengan label `<N> terjual` dan badge puncak `Terbanyak`.
  - Rincian **Komposisi Pembelian** per kategori dan daftar **Produk Terlaris**.

### 3. Manajemen Produk, Kalkulasi HPP & Stok Real-Time (`ProdukPage`)
- **Ringkasan Inventori Reaktif**: Menampilkan `Total Produk` dan `Stok Menipis` (`stock <= 0 || stock < initial_stock * 0.5`) yang langsung menghitung sisa stok efektif setelah dikurangi item di keranjang.
- **Pencarian & Filter Kategori**: Pencarian berdasarkan nama produk, jenis/kategori, atau barcode, serta 8 chip filter kategori (`Semua`, `Sembako`, `Makanan`, `Minuman`, `Snack`, `Bumbu Dapur`, `Kebutuhan Rumah`, `Lainnya`).
- **Form Tambah & Edit Produk Lengkap**:
  - Pilihan kategori (`Sembako`, `Makanan`, `Minuman`, `Snack`, `Umum`, `Lainnya` dengan input kategori kustom).
  - Pilihan satuan (`pcs`, `kg`, `liter`, `ml`, `gram`, `bungkus`, `botol`, `kemasan`) beserta **deteksi satuan otomatis** dari kolom `Berat / Ukuran` (contoh: mengetik `250ml` otomatis memilih satuan `ml`, `5kg` memilih `kg`, `500g` memilih `gram`, `2l` memilih `liter`).
  - **Upload Foto Produk Lokal**: Mengambil foto dari penyimpanan perangkat (di Android melalui `MethodChannel` `pickImage` yang mengompres gambar hingga maksimal `600px` JPEG quality `82` menjadi base64 data URI; di Windows melalui dialog pemilih file native).
  - **Kalkulasi HPP, Markup & Margin Otomatis**: Memasukkan **Modal / Produk**, **Ongkir (Opsional)**, dan **Harga Jual \*** langsung menampilkan simulasi **HPP / Produk** (`baseCostPrice + (shippingCost / stockCount).round()`), **Untung/Rugi**, **Markup (vs HPP) (%)**, dan **Margin (vs Jual) (%)**.
  - **Validasi Auto-Focus (`FocusNode`)**: Otomatis mengarahkan kursor dan menggulir ke kolom wajib yang belum terisi.
- **Proteksi Stok Real-Time**: Menekan `Tambah` langsung menyesuaikan sisa stok terhadap `CartService`; jika sisa stok mencapai `0`, tombol berubah menjadi `Habis` agar tidak terjadi penjualan melebihi stok.

### 4. Keranjang & Kasir POS (`KeranjangPage`, `CartService`, `QrisPaymentDialog`)
- Header nama toko yang tersinkronisasi reaktif dengan Profil Toko.
- Tampilan item keranjang lengkap dengan thumbnail foto produk dan kontrol kuantitas dengan penjagaan batas stok ketat.
- Pemilihan **Metode Pencatatan**: `Tunai`, `QRIS` (mendukung modal tampilan QRIS via `QrisPaymentDialog`), dan `Kasbon`.
- Ringkasan pembayaran bersih tanpa baris diskon serta penyimpanan transaksi (`Simpan`) yang langsung memperbarui stok produk dan riwayat transaksi secara lokal.

### 5. Riwayat Transaksi (`TransaksiPage`)
- Ringkasan `Omzet Hari Ini` dan `Jumlah Transaksi` dengan header nama toko yang tersinkronisasi reaktif.
- Pencarian transaksi berdasarkan ID invoice, nama pelanggan, metode pencatatan, maupun nama produk di dalam transaksi.
- Kartu riwayat transaksi lengkap dengan modal detail rincian item (`cartItems`) yang dibeli.
- Tombol **Reset** riwayat transaksi yang dilindungi konfirmasi PIN keamanan saat PIN aktif.

### 6. Profil Toko & Cadangkan Data CSV (`ProfilPage`, `MainActivity.kt`)
- **Identitas & Sinkronisasi Toko Reaktif**: Ubah Nama Toko (`store_name`) dan Kategori Toko (`store_category`) yang langsung diperbarui secara reaktif di `KeranjangPage`, `TransaksiPage`, `FullSidebar`, dan `QrisPaymentDialog`, disertai ringkasan `Produk Terdaftar` dan `Total Transaksi`.
- **Cadangkan Data Transaksi (CSV Offline)**:
  - Pilihan filter rentang waktu: `Semua`, `Perminggu` (7 hari terakhir), `Bulan`, dan `Tahun`.
  - Format ramah Microsoft Excel (`sep=,` dengan akhir baris CRLF `\r\n`) dan kolom `id_transaksi,waktu_transaksi,jenis_pembayaran,nama_produk,qty,harga_satuan_idr,total_transaksi_idr`.
  - **Sanitasi CSV Formula Injection**: Nilai teks yang diawali karakter formula berbahaya (`=`, `+`, `-`, `@`, `\t`, `\r`, termasuk setelah spasi awal) otomatis diawali tanda `'` agar aman saat dibuka di aplikasi spreadsheet.
  - Mendukung **Salin CSV** ke clipboard serta **Simpan CSV** langsung ke folder `Download` perangkat (`MediaStore` untuk Android Q+ / penyimpanan Download publik untuk Android di bawah Q, maupun folder `Downloads` di desktop).
- **Kosongkan Data Aplikasi**: Menghapus seluruh data lokal hingga kembali seperti baru pertama kali dipakai (dilindungi verifikasi PIN jika aktif).

---

## Ringkasan Pembaruan Terakhir (Changelog)

Berdasarkan riwayat pembaruan terakhir hingga `2026-11-14`:

1. **`Security Update` (`457fef1`)**:
   - Menambahkan kriptografi pure-Dart `SecurityCrypto` (SHA-256, HMAC-SHA256, PBKDF2-HMAC-SHA256 + salt acak 16-byte) serta migrasi otomatis kredensial lama.
   - Menambahkan rate limiting (maksimal 5x salah -> jeda 30 detik persisten), `AuthGate` auto-lock saat background, dialog konfirmasi PIN pada aksi destruktif (`Reset` transaksi & `Kosongkan Data Aplikasi`), dan sanitasi CSV formula injection.
   - Memperketat konfigurasi Android (`allowBackup="false"`, `usesCleartextTraffic="false"`, tanpa izin `INTERNET`, dukungan konfigurasi signing rilis opsional via `android/key.properties`).
2. **`Bugfix2 Final Version` (`d6a1cc5`)**:
   - Menyatukan sinkronisasi profil toko (`storeNameNotifier` & `storeCategoryNotifier`) agar pembaruan nama dan kategori toko di `ProfilPage` langsung terefleksi di `KeranjangPage`, `TransaksiPage`, `FullSidebar`, dan `QrisPaymentDialog`.
3. **`Stable bugfix Final version` (`5c06036`)**:
   - Menyesuaikan penamaan aplikasi menjadi `MANJUNI`, menambahkan satuan `ml` lengkap dengan deteksi otomatis ukuran `ml`, memperjelas label `Modal / Produk` dan `HPP / Produk`, serta menghapus baris `Diskon` pada ringkasan `KeranjangPage`.
4. **`Stable Version Final` (`dd6f081`)**:
   - Mengunci aplikasi ke mode 100% offline dengan skema penyimpanan bersih `_v2`, menerapkan PIN + 2 Nama Keamanan alfanumerik (termasuk alur ganti 2 nama serentak dengan PIN & karakter terakhir), kalkulasi `Ongkir` pada HPP, indikator `Markup` & `Margin`, validasi *auto-focus* form produk, thumbnail foto di keranjang, dan logo aplikasi terbaru (`assets/images/app_logo.png`).
5. **`Stable Version` (`3424289`)**:
   - Menambahkan integrasi native `MainActivity.kt` (`MethodChannel com.example.majunih/file_export`) untuk ekspor CSV ke folder `Download` dan unggah foto produk lokal, pengurangan stok real-time di `ProdukPage` & `KeranjangPage`, serta grafik tren produk terjual & ranking `Top Seller` di `DashboardPage` / `AnalyticsView`.

---

## Tech Stack & Konfigurasi

- **Framework**: Flutter & Dart SDK `^3.13.7` (`frontend/pubspec.yaml`, package `majunih`, versi `1.0.0+1`)
- **Paket Utama**:
  - `shared_preferences: ^2.3.2` — penyimpanan data lokal 100% offline
  - `qr_flutter: ^4.1.0` — rendering kode QR lokal pada modal pembayaran QRIS
  - `cupertino_icons: ^1.0.8` — aset ikon tambahan
  - `flutter_lints: ^6.0.0` — standar analisis statis Dart/Flutter
  - *(Catatan: dependensi `http` masih tercantum pada `pubspec.yaml`, namun jalur komunikasi jaringan tidak aktif pada aplikasi 100% offline dan izin `INTERNET` tidak dideklarasikan pada manifest Android)*
- **Android Native**: Kotlin + Android Gradle (`namespace` & `applicationId`: `com.example.majunih`, `android:label="MANJUNI"`, Java/Kotlin 17, `MainActivity.kt`)

---

## Struktur Direktori Proyek

```text
MANJUNI/
├── README.md                                  # Dokumentasi proyek (dokumen ini)
├── frontend/                                  # Aplikasi aktif Flutter (100% Offline)
│   ├── pubspec.yaml                           # Manifest & dependensi Flutter (package: majunih)
│   ├── analysis_options.yaml                  # Konfigurasi linter Dart/Flutter
│   ├── assets/
│   │   └── images/app_logo.png                # Logo utama aplikasi MANJUNI
│   ├── android/
│   │   └── app/
│   │       ├── build.gradle.kts               # Konfigurasi build & keystore rilis opsional
│   │       └── src/main/
│   │           ├── AndroidManifest.xml        # Tanpa izin INTERNET, allowBackup=false
│   │           └── kotlin/com/example/majunih/
│   │               └── MainActivity.kt        # MethodChannel file_export (CSV Downloads & pickImage)
│   ├── lib/
│   │   ├── main.dart                          # Inisialisasi loadLocalData() & runApp(MyApp)
│   │   ├── app.dart                           # Tema utama & AuthGate (auto-lock lifecycle)
│   │   ├── mobile_shell.dart                  # Shell navigasi 5 tab utama + badge keranjang
│   │   ├── shell.dart                         # Shell alternatif dengan FullSidebar drawer
│   │   ├── pages/
│   │   │   ├── login_page.dart                # Gerbang masuk offline & verifikasi/pemulihan PIN
│   │   │   ├── dashboard_page.dart            # Overview & toggle ke AnalyticsView
│   │   │   ├── analytics_page.dart            # Analitik penjualan vs pembelian, margin/markup & tren
│   │   │   ├── produk_page.dart               # Manajemen produk, HPP, foto lokal & stok real-time
│   │   │   ├── keranjang_page.dart            # Kasir POS, kontrol stok, Tunai/QRIS/Kasbon
│   │   │   ├── transaksi_page.dart            # Riwayat transaksi, detail item & reset ber-PIN
│   │   │   ├── profil_page.dart               # Identitas toko, PIN/Nama Keamanan & ekspor CSV
│   │   │   └── *_ui.dart                      # Wrapper UI halaman (keranjang, produk, profil, transaksi)
│   │   ├── services/
│   │   │   ├── api_service.dart               # Core state & penyimpanan lokal 100% offline (_v2)
│   │   │   ├── security_crypto.dart           # SHA-256, HMAC-SHA256 & PBKDF2-HMAC-SHA256
│   │   │   ├── cart_service.dart              # State keranjang lokal & sinkronisasi batas stok
│   │   │   ├── navigation_service.dart        # Pengaturan tab aktif dari shell navigasi
│   │   │   └── api_config.dart                # Konfigurasi historis
│   │   └── widgets/
│   │       ├── pin_confirm_dialog.dart        # Dialog verifikasi PIN sebelum aksi destruktif
│   │       ├── qris_payment_dialog.dart       # Dialog QRIS & nominal pembayaran
│   │       ├── custom_app_bar.dart            # Komponen AppBar kustom
│   │       └── full_sidebar.dart              # Sidebar navigasi dengan info toko reaktif
│   └── test/                                  # 12 berkas pengujian unit & widget Flutter
│       ├── analytics_page_test.dart
│       ├── custom_app_bar_test.dart
│       ├── dashboard_page_test.dart
│       ├── full_sidebar_test.dart
│       ├── keranjang_page_test.dart
│       ├── overview_and_profil_fixes_test.dart
│       ├── produk_page_test.dart
│       ├── profil_page_test.dart
│       ├── qris_payment_test.dart
│       ├── security_test.dart
│       ├── transaksi_page_test.dart
│       └── widget_test.dart
└── backend/                                   # Arsip prototipe awal Laravel (tidak digunakan oleh app offline)
```

---

## Cara Menjalankan, Menguji & Build Aplikasi

Seluruh perintah dijalankan dari direktori [`frontend/`](./frontend):

```bash
cd frontend
flutter pub get
flutter run
```

### Pengujian Otomatis (`frontend/test/`)

Terdapat 12 berkas test unit dan widget (termasuk pengujian keamanan kriptografi `PBKDF2`, rate-limit, sanitasi CSV, *auto-lock*, alur produk, keranjang, dashboard, analitik, profil, transaksi, dan QRIS). Untuk menjalankannya secara lokal:

```bash
cd frontend
flutter test
```

### Build APK Android Offline (Release)

```bash
cd frontend
flutter build apk --release
```

*(Opsional)* Untuk menandatangani build rilis menggunakan keystore sendiri, tambahkan berkas `frontend/android/key.properties` sesuai konfigurasi di [`frontend/android/build.gradle.kts`](./frontend/android/build.gradle.kts). Jika `key.properties` belum tersedia, konfigurasi build otomatis memakai *debug signing fallback* agar build lokal tetap berjalan.
