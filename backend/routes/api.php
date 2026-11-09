<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CapitalEntryController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\ExpenseController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PlanController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\QrisController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\WebhookController;

Route::prefix('v1')->group(function () {
    Route::get('/health', function () {
        return response()->json([
            'status' => 'ok',
        ]);
    });

    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    // Route webhook yang idempoten (tidak kena CSRF karena di routes/api.php)
    Route::post('/webhook/midtrans', [WebhookController::class, 'handle']);
    Route::post('/payments/midtrans/webhook', [WebhookController::class, 'handle']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/user', fn (Request $request) => $request->user()->load('business'));

        // Akses Kasir & Owner (Katalog, Scan Barcode, Transaksi, QRIS)
        Route::middleware('role:owner,cashier')->group(function () {
            Route::get('/categories', [CategoryController::class, 'index']);
            Route::get('/categories/{category}', [CategoryController::class, 'show']);
            Route::get('/products', [ProductController::class, 'index']);
            Route::get('/products/barcode/{barcode}', [ProductController::class, 'showByBarcode']);
            Route::get('/products/{product}', [ProductController::class, 'show']);
            Route::get('/transactions', [TransactionController::class, 'index']);
            Route::get('/transactions/{transaction}', [TransactionController::class, 'show']);
            Route::post('/transactions', [TransactionController::class, 'store']);
            Route::post('/transactions/{transaction}/confirm', [TransactionController::class, 'confirm']);
            Route::post('/transactions/{transaction}/cancel', [TransactionController::class, 'cancel']);
            Route::post('/transactions/{transaction}/pay/cash', [PaymentController::class, 'payWithCash']);
            Route::post('/transactions/{transaction}/pay/bank-transfer', [PaymentController::class, 'payWithBankTransfer']);
            Route::get('/transactions/{transaction}/receipt', [PaymentController::class, 'getReceipt']);
            Route::post('/transactions/{transaction}/qris', [QrisController::class, 'generate']);
            Route::get('/transactions/{transaction}/qris/status', [QrisController::class, 'status']);
            Route::get('/transactions/{transaction}/status', [QrisController::class, 'status']);
        });

        // Akses Khusus Owner (CRUD Produk, Kategori, Penyesuaian Stok, Void, Operasional, Modal, Target)
        Route::middleware('role:owner')->group(function () {
            Route::post('/categories', [CategoryController::class, 'store']);
            Route::put('/categories/{category}', [CategoryController::class, 'update']);
            Route::delete('/categories/{category}', [CategoryController::class, 'destroy']);

            Route::post('/products', [ProductController::class, 'store']);
            Route::put('/products/{product}', [ProductController::class, 'update']);
            Route::delete('/products/{product}', [ProductController::class, 'destroy']);
            Route::post('/products/{product}/stock', [ProductController::class, 'adjustStock']);

            Route::post('/transactions/{transaction}/void', [TransactionController::class, 'void']);

            Route::post('/expenses', [ExpenseController::class, 'store']);
            Route::post('/expenses/{expense}/void', [ExpenseController::class, 'void']);

            Route::post('/capital', [CapitalEntryController::class, 'store']);
            Route::delete('/capital/{capitalEntry}', [CapitalEntryController::class, 'destroy']);

            Route::post('/plans', [PlanController::class, 'store']);
            Route::put('/plans/{plan}', [PlanController::class, 'update']);
            Route::delete('/plans/{plan}', [PlanController::class, 'destroy']);
        });

        // Akses Owner & Partner (Dashboard, Laporan Biaya, Modal Usaha, Target)
        Route::middleware('role:owner,partner')->group(function () {
            Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
            Route::get('/expenses', [ExpenseController::class, 'index']);
            Route::get('/expenses/{expense}', [ExpenseController::class, 'show']);
            Route::get('/capital', [CapitalEntryController::class, 'index']);
            Route::get('/plans', [PlanController::class, 'index']);
            Route::get('/plans/{plan}', [PlanController::class, 'show']);
        });
    });
});
