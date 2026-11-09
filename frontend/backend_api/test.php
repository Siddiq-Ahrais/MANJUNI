<?php
require_once __DIR__ . '/koneksi.php';

$clientIp = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';

echo json_encode([
    "status" => "success",
    "message" => "Server Localhost Warung Majunih Aktif & Terhubung!",
    "timestamp" => date("Y-m-d H:i:s"),
    "server_mode" => $useMysql ? "MySQL Database (warung_db)" : "Local JSON Storage (Fallback Mode)",
    "client_ip" => $clientIp,
    "user_agent" => $userAgent
]);
?>
