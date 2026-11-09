<?php
require_once __DIR__ . '/koneksi.php';

if ($useMysql) {
    // Omzet & Transaksi
    $trxRes = $conn->query("SELECT COUNT(*) as total_trx, COALESCE(SUM(total_amount), 0) as total_omzet FROM transaksi");
    $trxData = $trxRes->fetch_assoc();
    $totalTrx = (int)$trxData['total_trx'];
    $totalOmzet = (int)$trxData['total_omzet'];

    // Stok Menipis
    $stockRes = $conn->query("SELECT COUNT(*) as low_count FROM produk WHERE low = 1 OR stock <= 5");
    $stockData = $stockRes->fetch_assoc();
    $lowCount = (int)$stockData['low_count'];

    // Total Produk
    $prodRes = $conn->query("SELECT COUNT(*) as prod_count FROM produk");
    $prodData = $prodRes->fetch_assoc();
    $prodCount = (int)$prodData['prod_count'];

    echo json_encode([
        "status" => "success",
        "data" => [
            "omzet" => $totalOmzet,
            "total_transaksi" => $totalTrx,
            "produk_terlaris" => "-",
            "stok_menipis" => $lowCount,
            "total_produk" => $prodCount
        ]
    ]);
} else {
    $data = getJsonData();
    $omzet = array_reduce($data["transactions"], function($carry, $item) {
        return $carry + ($item["amount"] ?? 0);
    }, 0);
    $lowCount = count(array_filter($data["products"], function($p) {
        return ($p["low"] ?? false) == true || ($p["stock"] ?? 0) <= 5;
    }));

    echo json_encode([
        "status" => "success",
        "data" => [
            "omzet" => $omzet,
            "total_transaksi" => count($data["transactions"]),
            "produk_terlaris" => "-",
            "stok_menipis" => $lowCount,
            "total_produk" => count($data["products"])
        ]
    ]);
}
?>
