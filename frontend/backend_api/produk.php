<?php
require_once __DIR__ . '/koneksi.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    if ($useMysql) {
        $result = $conn->query("SELECT * FROM produk ORDER BY id ASC");
        $products = [];
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $row['price'] = (int)$row['price'];
                $row['stock'] = (int)$row['stock'];
                $row['low'] = (bool)$row['low'];
                $products[] = $row;
            }
        }
        echo json_encode(["status" => "success", "data" => $products]);
    } else {
        $data = getJsonData();
        echo json_encode(["status" => "success", "data" => $data["products"]]);
    }
} elseif ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $name  = $input['name'] ?? '';
    $price = (int)($input['price'] ?? 0);
    $stock = (int)($input['stock'] ?? 0);
    $unit  = $input['unit'] ?? 'pcs';
    $low   = $stock <= 5;

    if (empty($name)) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Nama produk wajib diisi"]);
        exit;
    }

    if ($useMysql) {
        $stmt = $conn->prepare("INSERT INTO produk (name, price, stock, unit, low) VALUES (?, ?, ?, ?, ?)");
        $lowInt = $low ? 1 : 0;
        $stmt->bind_param("siisi", $name, $price, $stock, $unit, $lowInt);
        if ($stmt->execute()) {
            echo json_encode([
                "status" => "success",
                "message" => "Produk berhasil ditambahkan",
                "data" => [
                    "id" => $conn->insert_id,
                    "name" => $name,
                    "price" => $price,
                    "stock" => $stock,
                    "unit" => $unit,
                    "low" => $low
                ]
            ]);
        } else {
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "Gagal menambahkan produk"]);
        }
    } else {
        $data = getJsonData();
        $newId = count($data["products"]) > 0 ? max(array_column($data["products"], "id")) + 1 : 1;
        $newProduct = [
            "id" => $newId,
            "name" => $name,
            "price" => $price,
            "stock" => $stock,
            "unit" => $unit,
            "low" => $low
        ];
        $data["products"][] = $newProduct;
        saveJsonData($data);
        echo json_encode([
            "status" => "success",
            "message" => "Produk berhasil ditambahkan (fallback JSON)",
            "data" => $newProduct
        ]);
    }
} else {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method tidak diizinkan"]);
}
?>
