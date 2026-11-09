# Panduan Integrasi Localhost Warung Majunih (Flutter & XAMPP)

## 1. Pemisahan Frontend & Backend
Kamu hanya perlu fokus mengerjakan sisi **Frontend (Flutter)**. Kode backend tidak dicampur ke dalam source code Flutter, melainkan berjalan secara terpisah di **Localhost (XAMPP)**.

- **Frontend (Flutter)**: Menggunakan package `http` dan memanggil REST API endpoint JSON via [api_service.dart](file:///c:/Users/Administrator/Downloads/Documents/majunih/lib/services/api_service.dart) dan [api_config.dart](file:///c:/Users/Administrator/Downloads/Documents/majunih/lib/services/api_config.dart).
- **Backend (XAMPP / PHP)**: Berjalan di server web Apache XAMPP, merespons request data produk, transaksi, dan dashboard. File backend ini sudah disalin ke `C:\xampp\htdocs\api_warung`.

---

## 2. Aturan Penting Alamat Localhost di Flutter

| Perangkat Target | URL Localhost | Alasan |
| :--- | :--- | :--- |
| **Android Emulator** | `http://10.0.2.2/api_warung` | Di dalam emulator Android, `localhost` atau `127.0.0.1` mengarah ke sistem internal emulator itu sendiri. Untuk mengakses laptop host, wajib menggunakan `10.0.2.2`. |
| **HP Fisik Android/iOS (Wi-Fi)** | `http://192.168.1.68/api_warung` | HP fisik tidak bisa mengenali `localhost` maupun `10.0.2.2`. HP dan Laptop harus terhubung ke Wi-Fi yang sama, dan menggunakan alamat IPv4 laptop. |
| **Windows Desktop / Web Browser** | `http://127.0.0.1/api_warung` | Langsung mengakses loopback lokal komputer. |

> **Fitur Praktis:** Kamu tidak perlu mengubah kode setiap kali berganti perangkat! Buka tab **Profil** di aplikasi, lalu klik ikon pengaturan server atau tombol **Pengaturan Server Localhost** untuk langsung memilih target perangkat atau mengetikkan IP baru.

---

## 3. Langkah Menjalankan Backend XAMPP

1. Buka aplikasi **XAMPP Control Panel**.
2. Klik tombol **Start** pada modul **Apache**.
3. (Opsional) Klik tombol **Start** pada modul **MySQL**:
   - Jika ingin menggunakan MySQL: Buka browser ke `http://localhost/phpmyadmin`, buat database `warung_db`, lalu Import file `warung_db.sql`.
   - **Tanpa MySQL pun tetap jalan!** Backend ini sudah dilengkapi sistem *Auto Fallback JSON*, sehingga meskipun MySQL belum aktif, API tetap merespons dengan normal menggunakan file `db_store.json`.

---

## 4. Konfigurasi Android (Sudah Diterapkan)
Agar Android tidak memblokir koneksi HTTP ke localhost, pengaturan berikut sudah ditambahkan di [AndroidManifest.xml](file:///c:/Users/Administrator/Downloads/Documents/majunih/android/app/src/main/AndroidManifest.xml):
- Izin Internet: `<uses-permission android:name="android.permission.INTERNET"/>`
- Izin Cleartext (HTTP non-SSL): `android:usesCleartextTraffic="true"`
