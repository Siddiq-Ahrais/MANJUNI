-- Skrip Database Warung Sembako Majunih
CREATE DATABASE IF NOT EXISTS warung_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE warung_db;

-- Tabel Produk
CREATE TABLE IF NOT EXISTS produk (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price INT NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    unit VARCHAR(20) NOT NULL DEFAULT 'kemasan',
    low TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabel Transaksi
CREATE TABLE IF NOT EXISTS transaksi (
    id_trx INT AUTO_INCREMENT PRIMARY KEY,
    trx_code VARCHAR(20) NOT NULL UNIQUE,
    items_summary TEXT NOT NULL,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'Tunai',
    total_amount INT NOT NULL,
    time_formatted VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Database dimulai dalam keadaan bersih (0 produk & 0 transaksi)
-- INSERT data produk dan transaksi akan dilakukan langsung dari aplikasi User

