# MANJUNI (Manajemen UMKM Terkini) - Backend REST API v1.1

REST API backend untuk aplikasi mobile **MANJUNI (Manajemen UMKM Terkini)** berbasis **Laravel 11** dan **PHP 8.2**, dioptimalkan agar dapat berjalan pada hosting gratis (*InfinityFree, 000webhost, cPanel Shared Hosting, Railway, Render, dll.*).

---

## 🚀 Fitur Unggulan v1.1 (Sesuai PRD)

1. **Scan Barcode & Pencarian Cepat**:
   - Pencarian produk instan via barcode kemasan (EAN-13, dsb.) atau kode kustom.
   - Restock barang masuk langsung dengan pemindaian barcode (`POST /api/v1/products/restock-by-barcode`).
   - Penyesuaian stok fisik / stok opname (`POST /api/v1/products/{id}/adjust`).
2. **Alur Transaksi & Konfirmasi Pembayaran (Atomic DB Transaction)**:
   - Transaksi penjualan baru berstatus `pending` (menunggu pembayaran).
   - Stok **TIDAK berkurang** saat transaksi pending dibuat.
   - Stok berkurang secara otomatis dan tercatat di riwayat `stock_movements` seketika kasir/pemilik menekan **Konfirmasi Pembayaran** (`POST /api/v1/transactions/{id}/confirm`).
   - Validasi ketat: Konfirmasi ditolak otomatis bila stok tidak mencukupi saat konfirmasi dilakukan.
   - Pembatalan transaksi pending (`POST /api/v1/transactions/{id}/cancel`) tanpa menyentuh stok atau laporan.
   - Pembatalan transaksi lunas (*Void*) eksklusif oleh Pemilik (`POST /api/v1/transactions/{id}/void`) yang otomatis mengembalikan stok ke rak (*void_return*).
   - Penjualan langsung nominal untuk jasa / layanan tanpa produk (`direct_amount`).
3. **Multi-Tenant Data Isolation**:
   - Seluruh kueri dibatasi oleh `business_id`. Pengguna tidak dapat melihat atau mengubah data milik UMKM lain.
4. **Matriks Hak Akses Berbasis Peran (RBAC)**:
   - **Pemilik (`owner`)**: Akses penuh ke seluruh fitur dan pengaturan, kelola akun kasir/mitra, void, pengeluaran, modal, dan rencana.
   - **Kasir (`cashier`)**: Mencatat penjualan, memindai barcode, konfirmasi pembayaran, batalkan pending, melihat produk & stok.
   - **Mitra (`partner`)**: Read-only dasbor, laporan laba rugi, rekap arus kas, dan ringkasan modal.
5. **Dasbor & Laporan Keuangan Real-time**:
   - Dasbor omzet dan jumlah transaksi hari ini (hanya yang sudah lunas/completed).
   - Grafik tren harian (7 hari, 30 hari) dan bulanan.
   - Peringatan stok menipis (`stock <= min_stock`).
   - Laporan Laba Rugi per periode:
     $$\text{Laba Bersih} = \sum \text{Penjualan} - \sum (\text{Qty} \times \text{Harga Modal}) - \sum \text{Biaya Operasional}$$
   - Rekap Arus Kas (*Cash Flow*): Arus kas masuk (penjualan per metode bayar + modal masuk) vs arus kas keluar (operasional + penarikan modal).

---

## 🛠️ Persyaratan Sistem & Kompatibilitas Hosting Gratis

- **PHP**: `>= 8.2` (dengan ekstensi: `pdo_mysql` atau `pdo_sqlite`, `mbstring`, `openssl`, `curl`, `tokenizer`)
- **Web Server**: Apache / Nginx / LiteSpeed
- **Database**: MySQL 5.7+ / MariaDB 10.3+ atau SQLite 3
- **Dependency Locked**: `composer.json` dikunci pada platform `PHP 8.2.12` dan Symfony 7.x, sehingga **tidak akan menuntut PHP 8.4** saat di-deploy ke hosting gratis.

---

## 📦 Akun Demo (Seeder)

Setelah menjalankan `php artisan db:seed`, akun berikut siap digunakan:

| Peran | Email | Kata Sandi | Akses |
|---|---|---|---|
| **Pemilik (Owner)** | `owner@manjuni.id` | `password123` | Akses penuh seluruh sistem |
| **Kasir (Cashier)** | `kasir@manjuni.id` | `password123` | POS Kasir, Scan Barcode, Konfirmasi Bayar |
| **Mitra (Partner)** | `mitra@manjuni.id` | `password123` | Read-only Dasbor & Laporan |

Contoh barcode produk demo:
- `8991002105431` - Kopi Susu Gula Aren
- `8991002105432` - Americano Dingin
- `8992753123456` - Matcha Latte (Stok menipis: 3 / min: 5)
- `8993005128901` - Croissant Cokelat (Stok menipis: 4 / min: 5)
- `8995507113344` - Kentang Goreng Crispy
- `8994506112233` - Nasi Goreng Spesial MAJUNIH

---

## 🌐 Daftar Endpoint REST API (`/api/v1`)

### 1. Autentikasi
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | Public | Pendaftaran Pemilik & Pembuatan Usaha |
| `POST` | `/api/v1/auth/login` | Public | Login pengguna, menghasilkan token Sanctum |
| `POST` | `/api/v1/auth/logout` | Auth | Logout dan mencabut token saat ini |
| `GET` | `/api/v1/auth/profile` | Auth | Menampilkan profil pengguna & info usaha |
| `POST` | `/api/v1/auth/password` | Auth | Memperbarui kata sandi pengguna |

### 2. Manajemen Pengguna (Kasir & Mitra)
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/users` | Pemilik | Daftar staf kasir dan mitra usaha |
| `POST` | `/api/v1/users` | Pemilik | Membuat akun kasir atau mitra baru |
| `GET` | `/api/v1/users/{id}` | Pemilik | Detail pengguna |
| `PUT/PATCH` | `/api/v1/users/{id}` | Pemilik | Memperbarui data pengguna |
| `POST` | `/api/v1/users/{id}/toggle-status` | Pemilik | Mengaktifkan / menonaktifkan akun |

### 3. Produk & Kategori
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/categories` | Pemilik, Kasir | Daftar kategori produk |
| `POST` | `/api/v1/categories` | Pemilik | Tambah kategori baru |
| `PUT/PATCH` | `/api/v1/categories/{id}` | Pemilik | Edit nama kategori |
| `DELETE` | `/api/v1/categories/{id}` | Pemilik | Hapus kategori |
| `GET` | `/api/v1/products` | Pemilik, Kasir | Daftar produk (filter: search, category, low_stock) |
| `POST` | `/api/v1/products` | Pemilik | Tambah produk baru dengan barcode & stok awal |
| `GET` | `/api/v1/products/{id}` | Pemilik, Kasir | Detail produk |
| `GET` | `/api/v1/products/barcode/{barcode}` | Pemilik, Kasir | Cari produk spesifik via scan barcode |
| `PUT/PATCH` | `/api/v1/products/{id}` | Pemilik | Edit info produk |
| `DELETE` | `/api/v1/products/{id}` | Pemilik | Hapus produk (soft delete) |
| `POST` | `/api/v1/products/{id}/restock` | Pemilik | Restock barang masuk berdasarkan ID produk |
| `POST` | `/api/v1/products/restock-by-barcode` | Pemilik | Restock barang masuk via scan barcode |
| `POST` | `/api/v1/products/{id}/adjust` | Pemilik | Penyesuaian stok (stok opname) dengan alasan |
| `GET` | `/api/v1/products/{id}/stock-movements` | Pemilik, Kasir | Riwayat mutasi stok produk |

### 4. Transaksi Penjualan
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/transactions` | Pemilik, Kasir | Riwayat transaksi (filter status, metode, tanggal) |
| `POST` | `/api/v1/transactions` | Pemilik, Kasir | Catat penjualan baru (status otomatis `pending`) |
| `GET` | `/api/v1/transactions/{id}` | Pemilik, Kasir | Detail transaksi |
| `POST` | `/api/v1/transactions/{id}/confirm` | Pemilik, Kasir | Konfirmasi bayar (lunas, stok berkurang otomatis) |
| `POST` | `/api/v1/transactions/{id}/cancel` | Pemilik, Kasir | Batalkan transaksi yang masih pending |
| `POST` | `/api/v1/transactions/{id}/void` | Pemilik | Batalkan transaksi lunas & kembalikan stok |

### 5. Beban Operasional (Expenses)
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/expenses` | Pemilik | Daftar pengeluaran operasional |
| `POST` | `/api/v1/expenses` | Pemilik | Catat pengeluaran operasional baru |
| `GET` | `/api/v1/expenses/{id}` | Pemilik | Detail pengeluaran |
| `POST` | `/api/v1/expenses/{id}/void` | Pemilik | Void pengeluaran operasional |

### 6. Modal (Capital) & Rencana Usaha (Plans)
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/capital` | Pemilik, Mitra | Ringkasan total modal masuk/keluar & mutasi |
| `POST` | `/api/v1/capital` | Pemilik | Catat modal awal, tambahan modal, atau penarikan |
| `DELETE` | `/api/v1/capital/{id}` | Pemilik | Hapus entri modal |
| `GET` | `/api/v1/plans` | Pemilik | Daftar rencana usaha |
| `POST` | `/api/v1/plans` | Pemilik | Buat rencana usaha baru |
| `PUT/PATCH` | `/api/v1/plans/{id}` | Pemilik | Perbarui status/data rencana |
| `DELETE` | `/api/v1/plans/{id}` | Pemilik | Hapus rencana usaha |

### 7. Dasbor & Laporan
| Method | Endpoint | Hak Akses | Deskripsi |
|---|---|---|---|
| `GET` | `/api/v1/dashboard/summary` | Pemilik, Mitra | Omzet hari ini, produk menipis, grafik tren |
| `GET` | `/api/v1/reports/profit-loss` | Pemilik, Mitra | Laporan Laba Rugi per periode (omzet, HPP, laba) |
| `GET` | `/api/v1/reports/cash-flow` | Pemilik, Mitra | Laporan Arus Kas (uang masuk vs uang keluar) |

---

## 🌐 Panduan Deployment ke Free Hosting (InfinityFree / cPanel)

### Opsi A: Hosting dengan File Manager / FTP (InfinityFree / ByetHost)
1. Ekstrak kode backend ke komputer lokal, jalankan `composer install --no-dev --optimize-autoloader`.
2. Buat database MySQL di control panel hosting Anda (misal via cPanel / VistaPanel).
3. Salin isi file `.env.example` menjadi `.env`, lalu sesuaikan:
   ```dotenv
   APP_ENV=production
   APP_DEBUG=false
   APP_URL=https://nama-domain-anda.rf.gd

   DB_CONNECTION=mysql
   DB_HOST=sqlxxx.infinityfree.com
   DB_PORT=3306
   DB_DATABASE=if0_xxxx_manjuni
   DB_USERNAME=if0_xxxx
   DB_PASSWORD=kata_sandi_db_anda
   ```
4. Unggah seluruh folder backend ke dalam direktori `htdocs` (atau `public_html`).
5. File `.htaccess` bawaan di root backend akan secara otomatis mengarahkan seluruh permintaan web ke direktori `public/`.
6. Akses `https://nama-domain-anda.rf.gd/api/v1/health` di browser untuk memastikan status `{"status":"ok"}`.

### Opsi B: SQLite (Zero Configuration)
Bila hosting gratis Anda membatasi koneksi MySQL remote atau ribet mengatur kredensial database, Anda cukup mengatur di `.env`:
```dotenv
DB_CONNECTION=sqlite
DB_DATABASE=/home/username/htdocs/database/database.sqlite
```
(Pastikan file `database/database.sqlite` dan folder `storage/` memiliki izin tulis/write permission `775` atau `777`).

---

## 🧪 Menjalankan Pengujian (Automated Tests)

Semua pengujian unit dan fitur dapat dijalankan secara instan dengan:

```bash
php artisan test
```

Semua 32 skenario pengujian (147 assertions) mencakup autentikasi, isolasi data multi-tenant, CRUD produk, scan barcode, konfirmasi pembayaran, pengembalian stok saat void, dasbor, dan laporan laba rugi.
