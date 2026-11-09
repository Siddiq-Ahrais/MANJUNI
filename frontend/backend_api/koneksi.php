<?php
// Header CORS agar bisa diakses dari Flutter (Android Emulator, HP Fisik, Web, Windows)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$host = 'localhost';
$user = 'root';
$pass = '';
$db   = 'warung_db';

$conn = null;
$useMysql = false;

try {
    $conn = new mysqli($host, $user, $pass, $db);
    if (!$conn->connect_error) {
        $useMysql = true;
    }
} catch (Exception $e) {
    $useMysql = false;
}

$jsonFile = __DIR__ . '/db_store.json';

// Inisialisasi file JSON fallback jika belum ada
if (!file_exists($jsonFile)) {
    $initialData = [
        "products" => [],
        "transactions" => []
    ];
    file_put_contents($jsonFile, json_encode($initialData, JSON_PRETTY_PRINT));
}

function getJsonData() {
    global $jsonFile;
    if (file_exists($jsonFile)) {
        return json_decode(file_get_contents($jsonFile), true);
    }
    return ["products" => [], "transactions" => []];
}

function saveJsonData($data) {
    global $jsonFile;
    file_put_contents($jsonFile, json_encode($data, JSON_PRETTY_PRINT));
}
?>
