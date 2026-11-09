# MANJUNI - Dokumentasi REST API & Panduan Integrasi Mobile

Dokumentasi teknis ini ditujukan untuk pengembang aplikasi mobile (Flutter / Android) dan tim backend untuk mengintegrasikan seluruh fitur aplikasi POS kasir dan manajemen UMKM **MANJUNI**.

---

## 1. Spesifikasi Teknis Umum

### Base URL
* **Lokal / Android Emulator:** `http://10.0.2.2:8000/api/v1`
* **Lokal / HP Fisik (Wi-Fi):** `http://<IP-Laptop>:8000/api/v1` (contoh: `http://192.168.1.15:8000/api/v1`)
* **Production:** `https://api.manjuni.com/api/v1`

### Format Header
Semua request ke API wajib menyertakan header:
```http
Accept: application/json
Content-Type: application/json
```
Untuk endpoint yang membutuhkan autentikasi:
```http
Authorization: Bearer <token_sanctum>
```

### Matriks Hak Akses (Role-Based Access Control)
* **`owner`**: Akses penuh (kelola akun, CRUD produk, restock, void transaksi, operasional, modal, dan target).
* **`cashier`**: Akses operasional kasir (katalog produk, scan barcode kemasan, proses transaksi, batalkan pending, bayar tunai/QRIS/VA, cetak struk).
* **`partner`**: Akses pelaporan (dashboard ringkasan, laporan penjualan, biaya operasional, modal usaha, dan target).

---

## 2. Autentikasi & Akun

### 2.1 Registrasi Usaha & Owner Pertama
* **Endpoint:** `POST /api/v1/auth/register`
* **Akses:** Publik
* **Request Body:**
  ```json
  {
    "business_name": "Toko Manjuni POS",
    "name": "Ahmad Zani",
    "email": "zani@example.com",
    "password": "password123",
    "address": "Jl. Merdeka No. 45, Jakarta",
    "phone": "08123456789"
  }
  ```
* **Response (201 Created):**
  ```json
  {
    "user": {
      "id": 1,
      "business_id": 1,
      "name": "Ahmad Zani",
      "email": "zani@example.com",
      "role": "owner",
      "is_active": true
    },
    "business": {
      "id": 1,
      "name": "Toko Manjuni POS",
      "address": "Jl. Merdeka No. 45, Jakarta",
      "phone": "08123456789"
    },
    "token": "1|qW8eR9tY0u..."
  }
  ```

### 2.2 Login Pengguna (Kasir / Owner / Partner)
* **Endpoint:** `POST /api/v1/auth/login`
* **Akses:** Publik
* **Request Body:**
  ```json
  {
    "email": "kasir@example.com",
    "password": "password123"
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "user": {
      "id": 2,
      "name": "Siti Kasir",
      "email": "kasir@example.com",
      "role": "cashier",
      "business": {
        "id": 1,
        "name": "Toko Manjuni POS"
      }
    },
    "token": "2|aB3cD4eF5..."
  }
  ```

### 2.3 Logout
* **Endpoint:** `POST /api/v1/auth/logout`
* **Akses:** `owner`, `cashier`, `partner` (Bearer Token)
* **Response (200 OK):**
  ```json
  {
    "message": "Logout berhasil."
  }
  ```

### 2.4 Profil Akun & Usaha
* **Endpoint:** `GET /api/v1/user`
* **Akses:** `owner`, `cashier`, `partner` (Bearer Token)

---

## 3. Kategori Produk

### 3.1 Daftar Kategori
* **Endpoint:** `GET /api/v1/categories`
* **Akses:** `owner`, `cashier`
* **Response (200 OK):**
  ```json
  [
    {
      "id": 1,
      "business_id": 1,
      "name": "Makanan",
      "products_count": 12
    },
    {
      "id": 2,
      "business_id": 1,
      "name": "Minuman",
      "products_count": 8
    }
  ]
  ```

### 3.2 Tambah Kategori
* **Endpoint:** `POST /api/v1/categories`
* **Akses:** `owner`
* **Request Body:** `{"name": "Snack & Cemilan"}`
* **Response (201 Created)**

### 3.3 Edit & Hapus Kategori
* `PUT /api/v1/categories/{id}` — Edit nama kategori (*owner*)
* `DELETE /api/v1/categories/{id}` — Hapus kategori (*owner*)

---

## 4. Produk & Scan Barcode Kemasan

### 4.1 Katalog Produk
* **Endpoint:** `GET /api/v1/products`
* **Akses:** `owner`, `cashier`
* **Query Parameters:**
  * `category_id` (opsional): filter berdasarkan id kategori.
  * `search` (opsional): cari berdasarkan nama atau kode barcode.
  * `per_page` (opsional): jumlah data per halaman (default 20, max 100).
* **Response (200 OK):**
  ```json
  {
    "current_page": 1,
    "data": [
      {
        "id": 10,
        "category_id": 2,
        "name": "Kopi Arabika",
        "barcode": "8991234567890",
        "unit": "cup",
        "cost_price": 5000,
        "selling_price": 15000,
        "stock": 45,
        "min_stock": 5,
        "is_active": true,
        "category": {
          "id": 2,
          "name": "Minuman"
        }
      }
    ],
    "total": 1
  }
  ```

### 4.2 Scan Barcode Produk (Kamera HP Kasir)
* **Endpoint:** `GET /api/v1/products/barcode/{barcode}`
* **Akses:** `owner`, `cashier`
* **Response (200 OK):** Mengembalikan data satu produk secara instan.
* **Response (404 Not Found):** Jika barcode belum terdaftar di toko.

### 4.3 Tambah Produk Baru
* **Endpoint:** `POST /api/v1/products`
* **Akses:** `owner`
* **Request Body:**
  ```json
  {
    "name": "Kopi Espresso",
    "barcode": "8997788990011",
    "category_id": 2,
    "unit": "cup",
    "cost_price": 7000,
    "selling_price": 18000,
    "stock": 50,
    "min_stock": 5,
    "is_active": true
  }
  ```

### 4.4 Update & Hapus Produk
* `PUT /api/v1/products/{id}` — Perbarui data produk (*owner*)
* `DELETE /api/v1/products/{id}` — Soft delete produk (*owner*)

### 4.5 Penyesuaian Stok (Restock / Opname)
* **Endpoint:** `POST /api/v1/products/{id}/stock`
* **Akses:** `owner`
* **Request Body:**
  ```json
  {
    "type": "restock",        // Opsi: "restock" (tambah) atau "adjustment" (koreksi/opname)
    "quantity": 20,           // Positif untuk barang masuk, negatif untuk barang rusak/hilang
    "note": "Barang baru masuk dari supplier"
  }
  ```

---

## 5. Penjualan & Transaksi Kasir

### 5.1 Buat Transaksi Penjualan (Pending Checkout)
* **Endpoint:** `POST /api/v1/transactions`
* **Akses:** `owner`, `cashier`
* **Request Body:**
  ```json
  {
    "payment_method": "qris",  // Opsi: "cash", "qris", "transfer", "other"
    "note": "Meja No. 4",
    "items": [
      {
        "product_id": 10,
        "quantity": 2
      }
    ]
  }
  ```
* **Response (201 Created):**
  ```json
  {
    "id": 99,
    "business_id": 1,
    "user_id": 2,
    "total_amount": 30000,
    "payment_method": "qris",
    "status": "pending",
    "items": [
      {
        "id": 1,
        "product_id": 10,
        "quantity": 2,
        "unit_price": 15000,
        "cost_price": 5000,
        "subtotal": 30000,
        "product": {
          "name": "Kopi Arabika",
          "unit": "cup"
        }
      }
    ]
  }
  ```
  *(Catatan: Pada tahap ini, stok barang belum berkurang).*

### 5.2 Batalkan Transaksi Pending
* **Endpoint:** `POST /api/v1/transactions/{id}/cancel`
* **Akses:** `owner`, `cashier`

### 5.3 Void Transaksi Selesai (Pengembalian Stok)
* **Endpoint:** `POST /api/v1/transactions/{id}/void`
* **Akses:** `owner`
* **Request Body:** `{"void_reason": "Pelanggan salah pesan dan barang dikembalikan"}`
* **Keterangan:** Mengubah status transaksi jadi `void`, mengembalikan stok otomatis ke katalog, dan mencatat mutasi `void_return`.

---

## 6. Pembayaran Kasir (QRIS, Tunai, Bank VA, & Struk)

### 6.1 Generate QRIS Dinamis
* **Endpoint:** `POST /api/v1/transactions/{id}/qris`
* **Akses:** `owner`, `cashier`
* **Response (200 OK):**
  ```json
  {
    "transaction_id": 99,
    "payment_method": "qris",
    "qris": {
      "order_id": "TRX-99-1731123456",
      "gross_amount": 30000,
      "qr_string": "00020101021226680016ID.CO.SHOPEE.WWW01189360091800000000005204599953033605802ID5912TOKO MANJUNI6007JAKARTA61051234062070703A016304ABCD",
      "qr_url": "https://api.sandbox.midtrans.com/v2/qris/1731123456/qr-code",
      "expires_at": "2026-11-09T12:15:00+07:00",
      "status": "pending"
    }
  }
  ```

### 6.2 Polling Status Pembayaran QRIS
* **Endpoint:** `GET /api/v1/transactions/{id}/qris/status`
* **Akses:** `owner`, `cashier`
* **Response (200 OK):**
  ```json
  {
    "transaction_id": 99,
    "status": "completed",      // Berubah dari "pending" menjadi "completed" saat lunas
    "payment_method": "qris",
    "payment_reference": "TRX-99-1731123456",
    "total_amount": 30000,
    "paid_at": "2026-11-09T12:02:15.000000Z"
  }
  ```

### 6.3 Pembayaran Tunai (Cash) & Hitung Kembalian
* **Endpoint:** `POST /api/v1/transactions/{id}/pay/cash`
* **Akses:** `owner`, `cashier`
* **Request Body:**
  ```json
  {
    "cash_received": 50000,
    "note": "Uang pecahan pas"
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "message": "Pembayaran tunai berhasil.",
    "cash_received": 50000,
    "change_amount": 20000,
    "transaction": {
      "id": 99,
      "status": "completed",
      "payment_method": "cash"
    },
    "receipt": { ... }
  }
  ```

### 6.4 Pembayaran Transfer Bank (Virtual Account)
* **Endpoint:** `POST /api/v1/transactions/{id}/pay/bank-transfer`
* **Akses:** `owner`, `cashier`
* **Request Body:** `{"bank": "bca"}` *(Opsi: `bca`, `bni`, `bri`, `mandiri`, `permata`, `cimb`)*
* **Response (200 OK):** Mengembalikan nomor Virtual Account dan instruksi transfer.

### 6.5 Ambil Data Struk Belanja (Digital / Cetak Thermal)
* **Endpoint:** `GET /api/v1/transactions/{id}/receipt`
* **Akses:** `owner`, `cashier`
* **Response (200 OK):**
  ```json
  {
    "receipt": {
      "store": {
        "name": "Toko Manjuni POS",
        "address": "Jl. Merdeka No. 45, Jakarta",
        "phone": "08123456789"
      },
      "transaction": {
        "invoice_number": "INV-20261109-00099",
        "transaction_id": 99,
        "date": "09/11/2026 12:00",
        "cashier_name": "Siti Kasir"
      },
      "items": [
        {
          "product_name": "Kopi Arabika",
          "unit": "cup",
          "quantity": 2,
          "unit_price": 15000,
          "subtotal": 30000
        }
      ],
      "payment": {
        "total_amount": 30000,
        "payment_method": "CASH",
        "cash_received": 50000,
        "change_amount": 20000,
        "status": "completed",
        "paid_at": "09/11/2026 12:00:30"
      },
      "footer": {
        "greeting": "Terima kasih telah berbelanja!",
        "notice": "Barang yang sudah dibeli tidak dapat ditukar/dikembalikan."
      }
    }
  }
  ```

### 6.6 Webhook Callback Gateway (Server-to-Server)
* **Endpoint:** `POST /api/v1/webhook/midtrans`
* **Akses:** Publik (Verifikasi Signature SHA-512)
* **Sifat:** Idempoten (aman dipanggil berulang kali tanpa memotong stok ganda).

---

## 7. Biaya Operasional (Expenses)

* `GET /api/v1/expenses` — Daftar biaya operasional terpaginasi (*owner, partner*)
* `POST /api/v1/expenses` — Catat biaya operasional (*owner*)
  ```json
  {
    "expense_date": "2026-11-09",
    "category": "Listrik & Air",
    "amount": 250000,
    "note": "Token listrik toko bulan November"
  }
  ```
* `POST /api/v1/expenses/{id}/void` — Batalkan catatan biaya operasional (*owner*)

---

## 8. Modal Usaha (Capital Entries)

* `GET /api/v1/capital` — Daftar mutasi modal & ringkasan saldo modal berjalan (*owner, partner*)
* `POST /api/v1/capital` — Catat mutasi modal (*owner*)
  ```json
  {
    "entry_date": "2026-11-09",
    "type": "initial",        // Opsi: "initial" (modal awal), "addition" (setoran), "withdrawal" (tarik/prive)
    "amount": 10000000,
    "source_name": "Owner",
    "note": "Modal awal pembukaan toko"
  }
  ```
* `DELETE /api/v1/capital/{id}` — Hapus catatan modal (*owner*)

---

## 9. Rencana & Target Bisnis (Plans)

* `GET /api/v1/plans` — Daftar target bisnis (*owner, partner*)
* `POST /api/v1/plans` — Buat target bisnis baru (*owner*)
  ```json
  {
    "title": "Buka Cabang Baru di Jakarta Barat",
    "description": "Menyewa ruko dan pengadaan alat kopi",
    "due_date": "2027-05-01",
    "target_amount": 50000000,
    "status": "in_progress"   // Opsi: "planned", "in_progress", "done"
  }
  ```
* `PUT /api/v1/plans/{id}` — Perbarui progress/status target (*owner*)
* `DELETE /api/v1/plans/{id}` — Hapus target (*owner*)

---

## 10. Dashboard & Laporan

* **Endpoint:** `GET /api/v1/dashboard/summary`
* **Akses:** `owner`, `partner`
* **Response (200 OK):**
  ```json
  {
    "today": {
      "transactions": 15,
      "sales": 450000
    },
    "low_stock_products": 2,
    "sales_trend": [
      {
        "date": "2026-11-03",
        "total": 350000
      },
      {
        "date": "2026-11-04",
        "total": 420000
      }
    ]
  }
  ```

