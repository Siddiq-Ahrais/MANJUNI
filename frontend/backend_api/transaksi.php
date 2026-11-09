<?php
require_once __DIR__ . '/koneksi.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    if ($useMysql) {
        $result = $conn->query("SELECT * FROM transaksi ORDER BY id_trx DESC");
        $transactions = [];
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $transactions[] = [
                    "id" => $row['trx_code'],
                    "time" => $row['time_formatted'] ?? date("H:i", strtotime($row['created_at'])),
                    "items" => $row['items_summary'],
                    "method" => $row['payment_method'],
                    "amount" => (int)$row['total_amount'],
                    "synced" => true
                ];
            }
        }
        echo json_encode(["status" => "success", "data" => $transactions]);
    } else {
        $data = getJsonData();
        echo json_encode(["status" => "success", "data" => $data["transactions"]]);
    }
} elseif ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $itemsSummary = $input['items'] ?? '';
    $paymentMethod = $input['method'] ?? 'Tunai';
    $amount = (int)($input['amount'] ?? 0);
    $time = date('H:i');
    $trxCode = 'TRX-' . strtoupper(substr(uniqid(), -4));

    if (empty($itemsSummary) || $amount <= 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Item dan total belanja tidak valid"]);
        exit;
    }

    if ($useMysql) {
        $stmt = $conn->prepare("INSERT INTO transaksi (trx_code, items_summary, payment_method, total_amount, time_formatted) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("sssis", $trxCode, $itemsSummary, $paymentMethod, $amount, $time);
        if ($stmt->execute()) {
            echo json_encode([
                "status" => "success",
                "message" => "Transaksi berhasil dicatat",
                "data" => [
                    "id" => $trxCode,
                    "time" => $time,
                    "items" => $itemsSummary,
                    "method" => $paymentMethod,
                    "amount" => $amount,
                    "synced" => true
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "Gagal menyimpan transaksi ke database"]);
        }
    } else {
        $data = getJsonData();
        $newTrx = [
            "id" => $trxCode,
            "time" => $time,
            "items" => $itemsSummary,
            "method" => $paymentMethod,
            "amount" => $amount,
            "synced" => true
        ];
        array_unshift($data["transactions"], $newTrx);
        saveJsonData($data);
        echo json_encode([
            "status" => "success",
            "message" => "Transaksi berhasil dicatat (fallback JSON)",
            "data" => $newTrx
        ]);
    }
} else {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method tidak diizinkan"]);
}
?>
