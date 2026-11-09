# **PRD MAJUNIH (Manajemen UMKM Terkini) v1.1**

Nov 7, 2026 · @Ahmad

## **1\. Informasi Umum**

MAJUNIH versi 1.1 menjadikan scan barcode dan konfirmasi pembayaran sebagai fitur unggulan MVP: stok berkurang otomatis begitu pembayaran dikonfirmasi.

* **Nama Produk:** MAJUNIH (Manajemen UMKM Terkini)  
* **Versi:** 1.1  
* **Platform:** Aplikasi mobile (Flutter) dengan backend REST API (Laravel)  
* **Tema:** Local MSME & Creative Economy

### **Perubahan dari versi 1.0**

| Area | Versi 1.0 | Versi 1.1 |
| :---- | :---- | :---- |
| Pencatatan stok | Input manual | Scan barcode untuk mencari produk, menjual, dan restock |
| Status penjualan | Langsung tercatat sebagai selesai | Menunggu pembayaran (pending), lalu selesai setelah pembayaran dikonfirmasi |
| Pengurangan stok | Saat penjualan tercatat | Saat pembayaran dikonfirmasi |
| Pembayaran QRIS | Tidak ada | Metode pembayaran QRIS, dikonfirmasi manual oleh kasir tanpa payment gateway |
| Database | Tanpa barcode; status transaksi completed dan void | products.barcode; status pending dan cancelled; kolom paid\_at dan payment\_reference |
| Pemindaian barcode | Future Development | Masuk MVP (P0) |

## **2\. Latar Belakang**

### **Latar Belakang Masalah**

* **Hambatan aksesibilitas pada solusi digital yang ada:** Mayoritas aplikasi manajemen keuangan dan bisnis saat ini mengunci fitur esensial melalui skema berbayar (premium) dan sering mengganggu kenyamanan pengguna dengan tayangan iklan yang berlebihan. Hal ini menjadi barrier to entry bagi UMKM dengan keterbatasan modal operasional.  
* **Kebutuhan fungsionalitas inti yang sederhana:** Pelaku UMKM membutuhkan sistem digital yang praktis dan tidak terlalu kompleks, dengan fokus utama pada pencatatan riwayat transaksi harian, pengelolaan modal, dan kalkulasi laba bersih maupun laba rugi.  
* **Inefisiensi visibilitas operasional dan inventaris:** UMKM sering kesulitan melacak metrik vital bisnis secara real-time. Diperlukan dasbor terpusat yang memberikan visibilitas langsung terhadap omzet harian, tren penjualan, produk terlaris, serta peringatan dini untuk stok barang yang menipis.  
* **Pencatatan stok manual yang merepotkan:** UMKM umumnya mencatat stok masuk dan keluar dengan tulisan tangan atau mengetik satu per satu. Cara ini lambat, rawan salah, dan membuat stok di catatan berbeda dari stok di rak. Sistem stok gudang berbasis SAP (SAP Logon) yang pernah digunakan penulis di PT Comnet Plus (Iconnet) menjadi acuan alur: stok berkurang otomatis setelah barang dikonfirmasi keluar. MAJUNIH membawa alur itu ke versi ringan untuk UMKM lewat scan barcode di ponsel.  
* **Urgensi adaptasi di era ekonomi kreatif:** Terdapat kebutuhan mendesak untuk menyediakan alat bantu digital yang mendukung digitalisasi operasional UMKM lokal, guna mengoptimalkan manajemen bisnis dan meningkatkan daya saing mereka di pasar.

### **Rumusan Masalah**

1. Bagaimana merancang dan mengembangkan platform manajemen bisnis untuk UMKM yang menyediakan fitur pencatatan esensial secara inklusif tanpa pembatasan akses (premium) dan bebas dari distraksi iklan?  
2. Bagaimana menyederhanakan alur pencatatan operasional, seperti riwayat transaksi, perencanaan bisnis, dan laporan laba rugi, agar sesuai dengan tingkat literasi digital dan alur kerja harian UMKM?  
3. Bagaimana mengintegrasikan pemantauan performa bisnis, meliputi omzet harian, grafik penjualan periodik, dan manajemen stok otomatis, ke dalam satu antarmuka dasbor yang mudah dipahami?  
4. Bagaimana solusi digital ini dapat mempercepat digitalisasi UMKM lokal, mengoptimalkan efisiensi manajemen, dan meningkatkan daya saing mereka di dalam ekosistem ekonomi kreatif?  
5. Bagaimana mempercepat pencatatan stok dan penjualan lewat scan barcode, serta mengurangi stok otomatis saat pembayaran dikonfirmasi, tanpa integrasi payment gateway?

## **3\. Tujuan Produk**

Platform ini menghadirkan solusi manajemen operasional yang inklusif dan efisien bagi UMKM. Tujuan spesifiknya:

* **Aksesibilitas tanpa batasan (barrier-free):** Menyediakan aplikasi pencatatan dan manajemen bisnis yang fitur esensialnya dapat diakses penuh tanpa sistem berbayar (premium) dan bebas dari iklan, sehingga ramah bagi UMKM dengan keterbatasan modal.  
* **Digitalisasi pencatatan finansial yang sederhana:** Memfasilitasi pelaku UMKM dengan rekam jejak keuangan yang praktis untuk mencatat riwayat transaksi harian, mengelola modal, serta menghitung laba bersih dan laba rugi secara akurat.  
* **Visibilitas operasional dan inventaris terpusat:** Menghadirkan dasbor interaktif untuk memantau performa bisnis secara real-time, mencakup omzet harian, total transaksi, grafik tren penjualan, produk terlaris, hingga peringatan dini untuk stok yang menipis.  
* **Pencatatan stok cepat berbasis scan:** Memindai barcode produk untuk mencari produk, mencatat penjualan, dan restock, serta mengurangi stok otomatis saat pembayaran dikonfirmasi, tanpa mengetik data satu per satu.  
* **Peningkatan daya saing UMKM:** Mendorong digitalisasi operasional UMKM lokal untuk mengoptimalkan manajemen bisnis, memperluas perencanaan ke depan, dan menjadikan mereka lebih kompetitif dalam ekosistem ekonomi kreatif.

## **4\. Target Pengguna**

**Primary user:** Pemilik UMKM / pelaku usaha mandiri.

**Secondary user:**

* Karyawan operasional / kasir UMKM, pengguna harian fitur scan dan konfirmasi pembayaran  
* Mitra usaha / pemodal internal

## **5\. Fitur Utama**

MAJUNIH berfokus pada pencatatan usaha, bukan toko online: tidak ada katalog publik, keranjang belanja online, atau payment gateway. Fitur unggulan versi 1.1 adalah scan barcode dengan konfirmasi pembayaran (5.7). Prioritas P0 wajib ada di MVP, P1 dikerjakan bila waktu cukup.

### **5.1 Authentication & Authorization**

* Registrasi pemilik UMKM sekaligus pembuatan profil usaha (nama usaha, alamat, nomor telepon). (P0)  
* Login dan logout dengan email dan kata sandi; token akses disimpan aman di perangkat. (P0)  
* Tiga peran: Pemilik (akses penuh), Kasir (mencatat penjualan, melihat produk dan stok), Mitra (hanya melihat dasbor, laporan, dan ringkasan modal). (P0)  
* Pemilik membuat, menonaktifkan, dan mengatur peran akun kasir dan mitra. (P1)  
* Reset kata sandi. (P1)

### **5.2 Dashboard**

* Omzet hari ini dan jumlah transaksi hari ini; hanya transaksi yang sudah lunas yang dihitung. (P0)  
* Grafik tren penjualan harian (7 dan 30 hari) dan bulanan. (P0)  
* Daftar produk terlaris pada periode terpilih. (P0)  
* Peringatan stok menipis untuk produk dengan stok di bawah atau sama dengan batas minimum. (P0)  
* Ringkasan laba bersih bulan berjalan. (P1)

### **5.3 Management (Produk & Stok)**

* CRUD produk: nama, kategori, satuan, barcode, harga modal, harga jual, stok, dan batas minimum stok. (P0)  
* Stok berkurang otomatis saat pembayaran penjualan dikonfirmasi dan bertambah saat restock; setiap perubahan tercatat di riwayat stok. (P0)  
* Kategori produk. (P1)  
* Penyesuaian stok manual (stok opname) dengan catatan alasan. (P1)  
* Pencarian dan filter produk. (P1)

### **5.4 Transaksi & Riwayat**

* Catat penjualan: pilih atau scan satu atau beberapa produk, jumlah, metode pembayaran (tunai, QRIS, transfer, lainnya), tanggal, dan catatan. Penjualan berstatus menunggu pembayaran (pending) sampai dikonfirmasi. (P0)  
* Catat pengeluaran operasional (bahan, sewa, listrik dan air, gaji, lainnya). (P0)  
* Riwayat transaksi dengan filter tanggal, jenis, status, dan metode pembayaran. (P0)  
* Detail transaksi dan pembatalan (void) oleh Pemilik dengan alasan; transaksi tidak dihapus permanen. (P0)  
* Catat penjualan dengan nominal langsung tanpa memilih produk, untuk usaha jasa. (P1)

### **5.5 Modal & Perencanaan**

* Catat modal awal, tambahan modal, dan penarikan modal, termasuk nama pemodal bila ada. (P0)  
* Ringkasan total modal masuk dan modal ditarik. (P0)  
* Daftar rencana usaha: judul, deskripsi, target tanggal, target nominal (opsional), dan status (Direncanakan, Dikerjakan, Selesai). (P0)

### **5.6 Laporan Keuangan**

* Laporan laba rugi per periode (harian, mingguan, bulanan, rentang kustom): pendapatan, HPP, laba kotor, biaya operasional, dan laba bersih. (P0)  
* Rekap arus kas (uang masuk dan keluar) per periode. (P1)

### **5.7 Scan Barcode & Konfirmasi Pembayaran (fitur unggulan v1.1)**

Kamera ponsel membaca barcode produk. Stok berkurang otomatis setelah kasir mengonfirmasi bahwa pembayaran sudah diterima.

* Scan barcode untuk mencari produk. (P0)  
* Scan barcode saat penjualan: produk masuk ke keranjang, memindai produk yang sama lagi menambah jumlah. (P0)  
* Scan barcode saat restock (barang masuk) dengan mengisi jumlah. (P0)  
* Pasang barcode pada produk dengan memindai barcode kemasan atau mengetik manual; barcode unik per usaha. (P0)  
* Konfirmasi pembayaran: kasir menandai pembayaran sudah diterima (QRIS, tunai, transfer, atau lainnya). Saat itu status berubah dari pending ke lunas, stok berkurang, dan riwayat stok tercatat dalam satu database transaction. (P0)  
* Pembatalan penjualan pending sebelum dibayar; stok dan laporan tidak berubah. (P0)  
* Stok opname dengan scan. (P1)  
* Nomor referensi pembayaran dari aplikasi merchant (opsional). (P1)  
* Pembuatan label barcode untuk produk yang tidak punya barcode pabrik. (P1)

**Batasan pembayaran QRIS.** Pelanggan membayar ke QRIS merchant milik pemilik (misalnya dari Shopee atau Dana) di luar MAJUNIH. MAJUNIH tidak membaca status pembayaran secara otomatis, sehingga kasir memeriksa notifikasi di aplikasi merchant lalu menekan Konfirmasi Pembayaran. Pembacaan status otomatis lewat payment gateway masuk Future Development.

## **6\. User Flow**

### **Pemilik UMKM**

1. Mendaftar dan mengisi profil usaha.  
2. Mencatat modal awal.  
3. Menambahkan kategori dan produk beserta barcode (scan atau ketik), harga modal, harga jual, stok awal, dan batas minimum stok.  
4. Membuat akun kasir atau mitra bila dibutuhkan.  
5. Memindai barcode saat barang masuk untuk menambah stok (restock).  
6. Memantau dasbor: omzet harian, tren penjualan, produk terlaris, dan peringatan stok menipis.  
7. Mencatat pengeluaran operasional dan meninjau riwayat transaksi.  
8. Membuka laporan laba rugi per periode.  
9. Menyusun dan memperbarui daftar rencana usaha.

### **Karyawan / Kasir**

1. Login dengan akun yang dibuat Pemilik.  
2. Membuka halaman transaksi baru, memindai barcode produk (atau mencari manual), lalu mengatur jumlah.  
3. Menekan Bayar dan memilih metode pembayaran; transaksi berstatus menunggu pembayaran dan stok belum berubah.  
4. Pelanggan membayar. Untuk QRIS, pelanggan membayar ke QRIS merchant milik pemilik dan kasir memeriksa notifikasi di aplikasi merchant.  
5. Kasir menekan Konfirmasi Pembayaran: transaksi lunas dan stok berkurang otomatis. Peringatan muncul bila stok mencapai batas minimum.  
6. Bila pelanggan batal sebelum membayar, kasir membatalkan transaksi; stok dan laporan tidak berubah.  
7. Melihat riwayat transaksi dan stok produk.  
8. Bila salah input setelah lunas, meminta Pemilik membatalkan transaksi (void).

#### **Alur scan sampai stok berkurang**

![alur kasir: scan sampai stok berkurang · 2 keputusan][image1]

alur kasir: scan sampai stok berkurang · 2 keputusan

Stok baru berubah saat kasir menekan Konfirmasi Pembayaran; penjualan yang masih pending atau dibatalkan tidak menyentuh stok.

### **Mitra Usaha / Pemodal Internal**

1. Login dengan akun yang dibuat Pemilik.  
2. Melihat dasbor, laporan laba rugi, dan ringkasan modal (hanya baca).

## **7\. Functional Requirements**

FR-01 sampai FR-23 berasal dari versi 1.0 (FR-05, FR-07, FR-11, FR-13, dan FR-14 disesuaikan); FR-24 sampai FR-33 baru di versi 1.1.

| ID | Modul | Kebutuhan | Prioritas |
| :---- | :---- | :---- | :---- |
| FR-01 | Auth | Sistem memungkinkan pendaftaran Pemilik dan pembuatan profil usaha. | P0 |
| FR-02 | Auth | Sistem memvalidasi login dan memberikan token akses. | P0 |
| FR-03 | Auth | Sistem membatasi menu dan endpoint sesuai peran (Pemilik, Kasir, Mitra). | P0 |
| FR-04 | Auth | Pemilik dapat membuat dan menonaktifkan akun Kasir dan Mitra. | P1 |
| FR-05 | Produk | Sistem menyediakan CRUD produk dengan barcode, harga modal, harga jual, stok, dan batas minimum stok. | P0 |
| FR-06 | Produk | Sistem menyediakan kategori produk. | P1 |
| FR-07 | Stok | Stok berkurang otomatis saat pembayaran penjualan dikonfirmasi dan bertambah saat restock. | P0 |
| FR-08 | Stok | Sistem mencatat riwayat pergerakan stok per produk. | P0 |
| FR-09 | Stok | Pemilik dapat menyesuaikan stok manual dengan alasan. | P1 |
| FR-10 | Stok | Dasbor menampilkan produk dengan stok di bawah atau sama dengan batas minimum. | P0 |
| FR-11 | Transaksi | Pengguna berwenang dapat mencatat penjualan dengan satu atau lebih produk; penjualan berstatus menunggu pembayaran (pending) sampai dikonfirmasi. | P0 |
| FR-12 | Transaksi | Pemilik dapat mencatat pengeluaran operasional. | P0 |
| FR-13 | Transaksi | Sistem menampilkan riwayat transaksi dengan filter tanggal, jenis, status, dan metode pembayaran. | P0 |
| FR-14 | Transaksi | Pemilik dapat membatalkan (void) transaksi yang sudah lunas dengan alasan; stok dikembalikan otomatis. | P0 |
| FR-15 | Transaksi | Pengguna berwenang dapat mencatat penjualan dengan nominal langsung tanpa produk. | P1 |
| FR-16 | Modal | Pemilik dapat mencatat modal awal, tambahan modal, dan penarikan modal. | P0 |
| FR-17 | Perencanaan | Pemilik dapat membuat, mengubah, dan menghapus rencana usaha beserta statusnya. | P0 |
| FR-18 | Dashboard | Sistem menampilkan omzet dan jumlah transaksi hari ini. | P0 |
| FR-19 | Dashboard | Sistem menampilkan grafik tren penjualan harian dan bulanan. | P0 |
| FR-20 | Dashboard | Sistem menampilkan produk terlaris pada periode terpilih. | P0 |
| FR-21 | Laporan | Sistem menghitung laporan laba rugi per periode. | P0 |
| FR-22 | Laporan | Sistem menampilkan rekap arus kas per periode. | P1 |
| FR-23 | Umum | Seluruh fitur tersedia tanpa paywall dan tanpa iklan. | P0 |
| FR-24 | Scan | Pengguna berwenang dapat memindai barcode lewat kamera untuk mencari produk; bila produk tidak ditemukan, sistem menampilkan pesan yang jelas. | P0 |
| FR-25 | Scan | Pengguna berwenang dapat memindai barcode untuk menambahkan produk ke penjualan; memindai produk yang sama lagi menambah jumlah. | P0 |
| FR-26 | Scan | Pemilik dapat memindai barcode untuk restock dengan mengisi jumlah barang masuk. | P0 |
| FR-27 | Scan | Pemilik dapat memasang barcode pada produk dengan memindai atau mengetik manual; barcode unik per usaha. | P0 |
| FR-28 | Pembayaran | Pengguna berwenang dapat mengonfirmasi pembayaran penjualan pending (QRIS, tunai, transfer, atau lainnya); sistem mengubah status menjadi completed, mengurangi stok, dan mencatat stock\_movements dalam satu database transaction. | P0 |
| FR-29 | Pembayaran | Sistem menolak konfirmasi pembayaran bila stok produk tidak mencukupi saat dikonfirmasi. | P0 |
| FR-30 | Pembayaran | Pengguna berwenang dapat membatalkan penjualan pending sebelum dibayar; stok dan laporan tidak berubah. | P0 |
| FR-31 | Scan | Pemilik dapat melakukan stok opname dengan memindai barcode. | P1 |
| FR-32 | Pembayaran | Pengguna berwenang dapat mengisi nomor referensi pembayaran dari aplikasi merchant (opsional). | P1 |
| FR-33 | Scan | Aplikasi dapat membuat label barcode untuk produk yang tidak punya barcode pabrik. | P1 |

## **8\. Non-Functional Requirements**

Angka pada kolom kebutuhan adalah usulan awal dan dapat disesuaikan setelah pengujian.

| Aspek | Kebutuhan |
| :---- | :---- |
| Aksesibilitas | Tanpa iklan dan tanpa fitur esensial yang dikunci berbayar. |
| Usability | Antarmuka berbahasa Indonesia, nominal berformat Rupiah, dan satu penjualan dapat dicatat dalam beberapa ketukan (target: 5 ketukan atau kurang). |
| Scan barcode | Produk masuk ke keranjang segera setelah barcode terbaca (target: kurang dari 2 detik); input barcode manual tersedia bila kamera tidak dapat dipakai. |
| Performa | Operasi CRUD merespons di bawah 1 detik pada jaringan 4G; dasbor termuat di bawah 3 detik. |
| Keamanan | Kata sandi di-hash, komunikasi lewat HTTPS, token akses per perangkat, validasi input di sisi server, dan otorisasi per peran. Izin kamera hanya diminta saat fitur scan dibuka. |
| Isolasi data | Setiap kueri dibatasi business\_id; pengguna tidak dapat melihat data usaha lain. |
| Integritas data | Konfirmasi pembayaran (perubahan status, pengurangan stok, dan stock\_movements) berjalan dalam satu database transaction. |
| Kompatibilitas | Android sebagai target utama; iOS mengikuti karena basis kode Flutter yang sama (tidak diuji pada MVP). Fitur scan memerlukan kamera. |
| Keandalan | Backup database berkala (target: harian). |
| Maintainability | API berversi (/api/v1) dan terdokumentasi, kode mengikuti konvensi Laravel dan Flutter. |

## **9\. Teknologi yang Digunakan**

MAJUNIH memakai Flutter untuk aplikasi mobile dan Laravel untuk backend REST API. Data bergerak dalam alur berikut:

Aplikasi Flutter  \<-- JSON / HTTPS \--\>  Laravel REST API  \<--\>  MySQL

| Layer | Teknologi | Keterangan |
| :---- | :---- | :---- |
| Frontend (mobile) | Flutter (Dart) | Satu basis kode; Android sebagai target utama. |
| Scan barcode (mobile) | mobile\_scanner | Membaca barcode lewat kamera ponsel. |
| Backend | Laravel (PHP) | REST API berversi /api/v1, Eloquent ORM, migrasi, dan seeder. |
| Autentikasi | Laravel Sanctum | Token API per perangkat; otorisasi peran lewat Policy atau middleware. |
| Database | MySQL | Relasional, cocok untuk data transaksi dan laporan. |
| Komunikasi data | REST API, JSON | Request divalidasi dengan Form Request Laravel. |
| HTTP client (Flutter) | Dio atau package http | Menyimpan token dan menangani error API. |
| State management (Flutter) | Provider atau Riverpod | Dipilih tim saat implementasi. |
| Grafik (Flutter) | fl\_chart | Grafik tren penjualan di dasbor. |
| Version control | Git dan GitHub | Kolaborasi tim. |
| Pengujian API | Postman | Koleksi endpoint dibagikan ke tim. |

## **10\. Struktur Database**

Database MySQL berisi 10 tabel. Semua nominal disimpan sebagai bilangan bulat Rupiah (unsignedBigInteger). Setiap tabel memiliki created\_at dan updated\_at kecuali dinyatakan lain. Perubahan versi 1.1 hanya ada di tabel products dan transactions.

### **businesses**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| name | varchar | Nama usaha |
| address | text, null |  |
| phone | varchar, null |  |

### **users**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK | Mengacu ke businesses |
| name | varchar |  |
| email | varchar, unique |  |
| password | varchar | Hash |
| role | enum | owner, cashier, partner |
| is\_active | boolean | Default true |

### **categories**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| name | varchar | Unik per usaha |

### **products**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| category\_id | bigint, FK, null | Mengacu ke categories |
| name | varchar |  |
| barcode | varchar, null | Baru di v1.1. Unik per usaha (business\_id \+ barcode); null untuk produk tanpa barcode |
| unit | varchar | Pcs, porsi, kg, dan sebagainya |
| cost\_price | unsigned bigint | Harga modal per satuan |
| selling\_price | unsigned bigint | Harga jual per satuan |
| stock | int | Tidak boleh negatif |
| min\_stock | int | Batas peringatan stok menipis |
| is\_active | boolean | Default true |
| deleted\_at | timestamp, null | Soft delete |

### **transactions (penjualan)**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| user\_id | bigint, FK | Pencatat transaksi |
| transaction\_date | datetime | Tanggal penjualan; dipakai oleh dasbor dan laporan |
| total\_amount | unsigned bigint | Total penjualan |
| payment\_method | enum | cash, qris, transfer, other (qris baru di v1.1) |
| payment\_reference | varchar, null | Baru di v1.1. Nomor referensi dari aplikasi merchant, opsional |
| note | text, null |  |
| status | enum | pending, completed, cancelled, void (pending dan cancelled baru di v1.1) |
| paid\_at | datetime, null | Baru di v1.1. Waktu pembayaran dikonfirmasi; terisi saat status menjadi completed |
| void\_reason | text, null | Wajib bila void |
| voided\_by | bigint, FK, null | Mengacu ke users |
| voided\_at | datetime, null |  |

### **transaction\_items**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| transaction\_id | bigint, FK |  |
| product\_id | bigint, FK |  |
| quantity | int | Minimal 1 |
| unit\_price | unsigned bigint | Salinan harga jual saat transaksi dibuat |
| cost\_price | unsigned bigint | Salinan harga modal saat transaksi dibuat |
| subtotal | unsigned bigint | quantity x unit\_price |

### **expenses (pengeluaran operasional)**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| user\_id | bigint, FK | Pencatat |
| expense\_date | date |  |
| category | varchar | Bahan baku, sewa, listrik dan air, gaji, lainnya |
| amount | unsigned bigint |  |
| note | text, null |  |
| status | enum | completed, void |
| void\_reason | text, null |  |

### **capital\_entries (modal)**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| user\_id | bigint, FK | Pencatat |
| entry\_date | date |  |
| type | enum | initial, addition, withdrawal |
| amount | unsigned bigint |  |
| source\_name | varchar, null | Nama pemodal atau mitra |
| note | text, null |  |

### **stock\_movements**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| product\_id | bigint, FK |  |
| user\_id | bigint, FK |  |
| transaction\_item\_id | bigint, FK, null | Terisi untuk sale dan void\_return |
| type | enum | sale, restock, adjustment, void\_return. Pergerakan sale dicatat saat pembayaran dikonfirmasi, bukan saat transaksi pending dibuat |
| quantity\_change | int | Bertanda: negatif untuk stok keluar |
| stock\_after | int | Stok setelah perubahan |
| note | text, null |  |

### **plans (rencana usaha)**

| Kolom | Tipe | Keterangan |
| :---- | :---- | :---- |
| id | bigint, PK |  |
| business\_id | bigint, FK |  |
| user\_id | bigint, FK | Pembuat |
| title | varchar |  |
| description | text, null |  |
| due\_date | date, null |  |
| target\_amount | unsigned bigint, null |  |
| status | enum | planned, in\_progress, done |

## **11\. ERD (Entity Relationship Diagram)**

Versi 1.1 tidak menambah relasi baru; kolom barcode berada di tabel products.

### **11.1 Relasi Antar Entitas**

* Satu business memiliki banyak user, kategori, produk, transaksi, pengeluaran, entri modal, dan rencana.  
* Satu user mencatat banyak transaksi, pengeluaran, entri modal, pergerakan stok, dan rencana.  
* Satu category berisi banyak produk; produk boleh tanpa kategori.  
* Satu transaction memiliki banyak transaction\_items; satu product muncul di banyak transaction\_items.  
* Satu product memiliki banyak stock\_movements; satu transaction\_item dapat memicu stock\_movements (penjualan saat pembayaran dikonfirmasi, dan pengembalian saat void).

### **11.2 ERD Diagram (Text Representation)**

businesses 1 ──\< users  
businesses 1 ──\< categories  
businesses 1 ──\< products  
businesses 1 ──\< transactions  
businesses 1 ──\< expenses  
businesses 1 ──\< capital\_entries  
businesses 1 ──\< plans

categories 1 ──\< products

users 1 ──\< transactions      (user\_id, voided\_by)  
users 1 ──\< expenses  
users 1 ──\< capital\_entries  
users 1 ──\< stock\_movements  
users 1 ──\< plans

transactions 1 ──\< transaction\_items  
products     1 ──\< transaction\_items  
products     1 ──\< stock\_movements  
transaction\_items 1 ──\< stock\_movements  
Simbol 1 ──\< berarti satu ke banyak (one to many).

### **11.3 Ringkasan Relasi**

| Entitas induk | Relasi | Entitas anak | Foreign key |
| :---- | :---- | :---- | :---- |
| businesses | 1 : N | users | users.business\_id |
| businesses | 1 : N | categories | categories.business\_id |
| businesses | 1 : N | products | products.business\_id |
| businesses | 1 : N | transactions | transactions.business\_id |
| businesses | 1 : N | expenses | expenses.business\_id |
| businesses | 1 : N | capital\_entries | capital\_entries.business\_id |
| businesses | 1 : N | plans | plans.business\_id |
| categories | 1 : N | products | products.category\_id |
| users | 1 : N | transactions | transactions.user\_id, transactions.voided\_by |
| users | 1 : N | expenses | expenses.user\_id |
| users | 1 : N | capital\_entries | capital\_entries.user\_id |
| users | 1 : N | stock\_movements | stock\_movements.user\_id |
| users | 1 : N | plans | plans.user\_id |
| transactions | 1 : N | transaction\_items | transaction\_items.transaction\_id |
| products | 1 : N | transaction\_items | transaction\_items.product\_id |
| products | 1 : N | stock\_movements | stock\_movements.product\_id |
| transaction\_items | 1 : N | stock\_movements | stock\_movements.transaction\_item\_id |

## **12\. Rules & Constraints**

### **Hak akses per peran**

| Aksi | Pemilik | Kasir | Mitra |
| :---- | :---- | :---- | :---- |
| Kelola produk, kategori, dan stok (termasuk restock) | Ya | Lihat saja | Tidak |
| Scan barcode untuk mencari produk | Ya | Ya | Tidak |
| Scan barcode untuk restock | Ya | Tidak | Tidak |
| Catat penjualan dan konfirmasi pembayaran | Ya | Ya | Tidak |
| Batalkan penjualan yang belum dibayar (pending) | Ya | Ya | Tidak |
| Void transaksi yang sudah lunas | Ya | Tidak | Tidak |
| Catat pengeluaran | Ya | Tidak | Tidak |
| Catat modal dan kelola rencana | Ya | Tidak | Tidak |
| Lihat dasbor dan laporan | Ya | Tidak | Ya |
| Kelola akun pengguna | Ya | Tidak | Tidak |

### **Aturan data dan bisnis**

* Semua data milik satu usaha; setiap kueri difilter business\_id, dan satu akun hanya milik satu usaha.  
* Setiap usaha memiliki tepat satu Pemilik pada versi 1.0 dan 1.1.  
* Harga dan nominal tidak boleh negatif; jumlah item minimal 1; nominal berupa bilangan bulat Rupiah.  
* Penjualan berstatus pending tidak mengubah stok, dasbor, maupun laporan. Stok berkurang hanya saat pembayaran dikonfirmasi.  
* Konfirmasi pembayaran (status menjadi completed, paid\_at terisi, pengurangan stok, dan stock\_movements) berjalan atomik dalam satu database transaction.  
* Stok tidak boleh negatif; konfirmasi pembayaran ditolak bila jumlah melebihi stok saat dikonfirmasi.  
* Penjualan pending yang dibatalkan berstatus cancelled dan tidak mengubah stok maupun laporan.  
* Barcode unik per usaha; produk tanpa barcode tetap dapat dijual lewat pencarian manual.  
* QRIS dibayar lewat aplikasi merchant di luar MAJUNIH; konfirmasi pembayaran dilakukan manual oleh Kasir atau Pemilik.  
* Harga jual dan harga modal disalin ke transaction\_items saat transaksi dibuat, sehingga perubahan harga produk tidak mengubah riwayat.  
* Transaksi dan pengeluaran tidak dihapus permanen; hanya dapat di-void oleh Pemilik dengan alasan. Void transaksi lunas mengembalikan stok (stock\_movements bertipe void\_return) dan mengeluarkan data itu dari laporan.  
* Produk yang pernah terjual tidak dihapus permanen, hanya dinonaktifkan (soft delete).  
* Tanggal transaksi, pengeluaran, dan modal tidak boleh di masa depan.  
* Stok dianggap menipis bila stock kurang dari atau sama dengan min\_stock.  
* Produk terlaris dihitung dari total quantity pada transaksi berstatus completed dalam periode terpilih.  
* Tambahan dan penarikan modal tidak dihitung sebagai pendapatan atau biaya pada laporan laba rugi.  
* Tidak ada iklan dan tidak ada fitur yang dikunci berbayar.

### **Rumus laporan laba rugi**

\\text{Laba Bersih} \= \\sum \\text{Penjualan} \- \\sum (\\text{Qty} \\times \\text{Harga Modal}) \- \\sum \\text{Biaya Operasional}  
Penjualan dan biaya operasional hanya menghitung data berstatus completed. Selisih penjualan dan HPP (jumlah Qty × Harga Modal) adalah laba kotor.

## **13\. Future Development**

Pemindaian barcode sudah pindah dari daftar ini ke MVP (bagian 5.7).

* Integrasi pembayaran otomatis: status QRIS dibaca lewat webhook payment gateway (misalnya Midtrans atau Xendit), sehingga pengurangan stok terjadi tanpa konfirmasi manual kasir.  
* Mode offline dengan sinkronisasi otomatis saat koneksi kembali.  
* Ekspor laporan ke PDF dan Excel, serta cetak atau bagikan nota.  
* Notifikasi push untuk stok menipis dan ringkasan harian.  
* Pencatatan hutang dan piutang.  
* Dukungan beberapa cabang dan beberapa pemilik.  
* Pencatatan kanal penjualan (misalnya toko online) sebagai ekstensi dari riwayat transaksi.  
* Prediksi penjualan dan rekomendasi restock berbasis riwayat.  
* Versi iOS dan versi web untuk Pemilik.

## **14\. Catatan Tambahan**

* **Lingkup:** MAJUNIH adalah alat pencatatan UMKM (riwayat transaksi, modal, laba rugi, stok). Kebutuhan khas toko online seperti katalog, ongkos kirim, dan integrasi marketplace berada di luar versi 1.0 dan 1.1.  
* **Prioritas MVP:** Kerjakan seluruh item P0 lebih dulu karena lingkup perlu tetap kecil; item P1 hanya bila waktu tersisa. Alur scan, konfirmasi pembayaran, dan stok berkurang otomatis harus berjalan penuh sebelum fitur P0 lain dipoles, karena itu inti demo.  
* **Penyesuaian template:** Bagian awal template berisi sisa dokumen LMS (Module & Lesson, Enrollment, Progress Tracking, Student dan Instructor). Bagian itu diganti menjadi Transaksi, Modal & Perencanaan, Laporan, serta peran Pemilik, Kasir, dan Mitra.  
* **Asumsi:** Database MySQL, mata uang Rupiah saja, satu usaha per akun, angka pada Non-Functional Requirements berupa target usulan, dan pembayaran QRIS terjadi di aplikasi merchant di luar MAJUNIH.  
* **Pertanyaan terbuka:** Sumber keberlanjutan biaya karena aplikasi tanpa iklan dan tanpa premium; apakah Mitra memerlukan akun sendiri atau cukup laporan yang dibagikan; tempat hosting backend; dan apakah kasir perlu mengisi nomor referensi pembayaran QRIS agar mudah dicocokkan dengan aplikasi merchant.

### **Usulan rencana pengerjaan 7 hari**

| Hari | Fokus |
| :---- | :---- |
| 1 | Finalisasi PRD, migrasi database, auth dan peran, seeder data demo |
| 2-3 | CRUD produk dengan barcode, restock, dan riwayat stok di backend |
| 3-4 | Transaksi dengan scan dan konfirmasi pembayaran dalam satu database transaction |
| 4-5 | Dasbor (omzet, grafik, stok menipis) dan laporan laba rugi |
| 6 | Modal, rencana usaha, dan perapian UI; pangkas bila waktu tidak cukup |
| 7 | Testing, perbaikan bug, slide, dan latihan demo |

[image1]: <data:image/png;base64,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>