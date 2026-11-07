# MANJUNI

Project Manager, QA, Backend: Raisul  
Frontend, UI/UX: Ferdi  
Backend/AI Engineer: Zani  
QA, UI/UX: Azka

## Backend

Backend berada di folder [`backend/`](./backend) dan menggunakan Laravel 12, PHP 8.2+, Laravel Sanctum, serta MySQL.

Database mengikuti spesifikasi aplikasi mobile: `businesses`, `users`, `categories`, `products`, `transactions`, `transaction_items`, `expenses`, `capital_entries`, `stock_movements`, dan `plans`.

```powershell
cd backend
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

Endpoint mobile:

- `POST /api/v1/auth/register` - membuat bisnis dan owner pertama.
- `POST /api/v1/auth/login` - mendapatkan token perangkat.
- `POST /api/v1/auth/logout` - mencabut token aktif.
- `GET /api/v1/products?search=...` - daftar produk atau pencarian barcode.
- `GET /api/v1/products/barcode/{barcode}` - mengambil produk hasil scan.
- `POST /api/v1/transactions` - membuat penjualan pending tanpa mengubah stok.
- `POST /api/v1/transactions/{id}/confirm` - mengonfirmasi pembayaran, mengurangi stok, dan mencatat pergerakan stok.
- `GET /api/v1/dashboard/summary` - ringkasan penjualan, stok menipis, dan tren 7 hari.

Selain health, register, dan login, endpoint memakai header `Authorization: Bearer <token>`.

Hak akses dasar:

- `owner`: akses penuh dan pengelolaan akun.
- `cashier`: melihat produk, scan barcode, dan proses penjualan.
- `partner`: dashboard dan laporan.

Akses yang tidak sesuai role mengembalikan HTTP `403`.

Aturan penjualan:

- Harga dan nominal disimpan sebagai integer Rupiah dan tidak boleh negatif.
- Kuantitas item minimal `1`.
- Stok hanya berkurang saat pembayaran dikonfirmasi.
- Transaksi pending tidak masuk dashboard atau laporan penjualan.
- Harga transaksi disalin ke `transaction_items`, sehingga perubahan harga produk tidak mengubah riwayat.
