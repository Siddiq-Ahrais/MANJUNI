# MANJUNI

Project Manager, QA, Backend: Raisul  
Frontend, UI/UX: Ferdi  
Backend/AI Engineer: Zani  
QA, UI/UX: Azka

## Backend

Backend berada di folder [`backend/`](./backend) dan menggunakan Laravel 11/12, PHP 8.2+, Laravel Sanctum, serta MySQL.

Database mencakup 10 model utama: `businesses`, `users`, `categories`, `products`, `transactions`, `transaction_items`, `expenses`, `capital_entries`, `stock_movements`, dan `plans`.

```powershell
cd backend
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

---

### Endpoint REST API Mobile:

#### 1. Autentikasi & Akun
- `POST /api/v1/auth/register` - membuat bisnis dan akun owner pertama.
- `POST /api/v1/auth/login` - autentikasi kasir/owner, mendapatkan token Sanctum.
- `POST /api/v1/auth/logout` - mencabut token aktif.
- `GET /api/v1/user` - mengambil data profil akun dan profil bisnis aktif.

#### 2. Kategori Produk
- `GET /api/v1/categories` - daftar kategori dengan jumlah produk (*cashier, owner*).
- `GET /api/v1/categories/{id}` - detail kategori (*cashier, owner*).
- `POST /api/v1/categories` - tambah kategori (*owner*).
- `PUT /api/v1/categories/{id}` - edit nama kategori (*owner*).
- `DELETE /api/v1/categories/{id}` - hapus kategori (*owner*).

#### 3. Produk, Scan Barcode, & Stok
- `GET /api/v1/products?category_id=...&search=...` - katalog produk terpaginasi (*cashier, owner*).
- `GET /api/v1/products/barcode/{barcode}` - scan barcode kemasan barang (*cashier, owner*).
- `GET /api/v1/products/{id}` - detail produk (*cashier, owner*).
- `POST /api/v1/products` - tambah produk baru dan stok awal (*owner*).
- `PUT /api/v1/products/{id}` - perbarui data produk & harga (*owner*).
- `DELETE /api/v1/products/{id}` - soft delete produk (*owner*).
- `POST /api/v1/products/{id}/stock` - restock masuk atau opname stok rusak/hilang (*owner*).

#### 4. Penjualan & Transaksi
- `GET /api/v1/transactions?status=...&date=...` - riwayat transaksi terpaginasi (*cashier, owner*).
- `GET /api/v1/transactions/{id}` - detail transaksi dan rincian belanja (*cashier, owner*).
- `POST /api/v1/transactions` - membuat checkout pending tanpa memotong stok (*cashier, owner*).
- `POST /api/v1/transactions/{id}/confirm` - konfirmasi pembayaran manual (*cashier, owner*).
- `POST /api/v1/transactions/{id}/cancel` - membatalkan transaksi pending (*cashier, owner*).
- `POST /api/v1/transactions/{id}/void` - membatalkan transaksi completed & mengembalikan stok (*owner*).

#### 5. Pembayaran Kasir (QRIS, Tunai, Bank VA, & Struk)
- `POST /api/v1/transactions/{id}/qris` - generate QRIS dinamis (`qr_string`, `qr_url`) (*cashier, owner*).
- `GET /api/v1/transactions/{id}/qris/status` - polling status pembayaran QRIS (*cashier, owner*).
- `POST /api/v1/transactions/{id}/pay/cash` - bayar tunai dengan kalkulasi otomatis kembalian (*cashier, owner*).
- `POST /api/v1/transactions/{id}/pay/bank-transfer` - bayar transfer Virtual Account bank (*cashier, owner*).
- `GET /api/v1/transactions/{id}/receipt` - ambil data struk belanja digital / cetak thermal (*cashier, owner*).
- `POST /api/v1/webhook/midtrans` - webhook publik idempoten notifikasi pembayaran gateway.

#### 6. Biaya Operasional (Expenses)
- `GET /api/v1/expenses?category=...&date=...` - daftar pengeluaran operasional toko (*owner, partner*).
- `GET /api/v1/expenses/{id}` - detail pengeluaran (*owner, partner*).
- `POST /api/v1/expenses` - mencatat biaya operasional seperti listrik, sewa, gaji (*owner*).
- `POST /api/v1/expenses/{id}/void` - membatalkan catatan biaya (*owner*).

#### 7. Modal Usaha (Capital Entries)
- `GET /api/v1/capital` - ringkasan modal awal, tambahan modal, penarikan (prive), & modal berjalan (*owner, partner*).
- `POST /api/v1/capital` - mencatat modal masuk/keluar (*owner*).
- `DELETE /api/v1/capital/{id}` - menghapus catatan modal (*owner*).

#### 8. Target & Rencana Usaha (Plans)
- `GET /api/v1/plans?status=...` - daftar rencana target bisnis (*owner, partner*).
- `GET /api/v1/plans/{id}` - detail rencana (*owner, partner*).
- `POST /api/v1/plans` - membuat target bisnis baru (*owner*).
- `PUT /api/v1/plans/{id}` - memperbarui status target (*owner*).
- `DELETE /api/v1/plans/{id}` - menghapus target (*owner*).

#### 9. Dashboard & Ringkasan
- `GET /api/v1/dashboard/summary` - omset hari ini, total transaksi, stok menipis, dan tren 7 hari (*owner, partner*).

---

### Hak Akses (Role-Based Access Control)
- `owner`: akses penuh pengelolaan akun, katalog produk, restock, void transaksi, operasional, modal, dan target.
- `cashier`: melihat produk, scan barcode kemasan, proses transaksi, batalkan pending, bayar QRIS/tunai/VA, cetak struk.
- `partner`: dashboard ringkasan, laporan penjualan, biaya operasional, modal usaha, dan target bisnis.

Akses tanpa hak akses mengembalikan HTTP `403 Forbidden`.

### Aturan Data & Mutasi Stok:
- Semua nominal uang disimpan sebagai integer Rupiah tanpa desimal.
- Kuantitas item transaksi minimal `1`.
- Stok barang hanya berkurang saat pembayaran berstatus `completed` (tunai atau webhook gateway).
- Transaksi pending tidak dimasukkan ke dalam laporan penjualan/dashboard.
- Harga barang di-snapshot ke `transaction_items` saat checkout dibuat.
- Setiap mutasi stok (penjualan, restock masuk, opname, void) tercatat otomatis di `stock_movements`.
