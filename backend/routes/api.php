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
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\WebhookController;

Route::prefix('v1')->group(function () {
    Route::get('/health', function () {
        return response()->json([
            'status' => 'ok',
            'app' => 'MANJUNI API v1.1',
            'timestamp' => now()->toIso8601String(),
        ]);
    });

    // Public Auth
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    // Route webhook Midtrans yang idempoten (tidak kena CSRF karena di routes/api.php)
    Route::post('/webhook/midtrans', [WebhookController::class, 'handle']);
    Route::post('/payments/midtrans/webhook', [WebhookController::class, 'handle']);

    // Authenticated Routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/profile', [AuthController::class, 'profile']);
        Route::post('/auth/password', [AuthController::class, 'updatePassword']);
        Route::get('/user', fn (Request $request) => $request->user()->load('business'));

        // 1. Shared Access: Owner & Cashier (Katalog, Scan Barcode, Transaksi, QRIS, Struk)
        Route::middleware('role:owner,cashier')->group(function () {
            // Categories Read
            Route::get('/categories', [CategoryController::class, 'index']);
            Route::get('/categories/{category}', [CategoryController::class, 'show']);

            // Products Read & Barcode
            Route::get('/products', [ProductController::class, 'index']);
            Route::get('/products/barcode/{barcode}', [ProductController::class, 'showByBarcode']);
            Route::get('/products/{product}', [ProductController::class, 'show']);
            Route::get('/products/{product}/stock-movements', [ProductController::class, 'stockMovements']);

            // Transactions (Kasir & Pemilik)
            Route::get('/transactions', [TransactionController::class, 'index']);
            Route::get('/transactions/{transaction}', [TransactionController::class, 'show']);
            Route::post('/transactions', [TransactionController::class, 'store']);
            Route::post('/transactions/{transaction}/confirm', [TransactionController::class, 'confirm']);
            Route::post('/transactions/{transaction}/cancel', [TransactionController::class, 'cancel']);

            // Payment & QRIS (dari origin/qris)
            Route::post('/transactions/{transaction}/pay/cash', [PaymentController::class, 'payWithCash']);
            Route::post('/transactions/{transaction}/pay/bank-transfer', [PaymentController::class, 'payWithBankTransfer']);
            Route::get('/transactions/{transaction}/receipt', [PaymentController::class, 'getReceipt']);
            Route::post('/transactions/{transaction}/qris', [QrisController::class, 'generate']);
            Route::get('/transactions/{transaction}/qris/status', [QrisController::class, 'status']);
            Route::get('/transactions/{transaction}/status', [QrisController::class, 'status']);
        });

        // 2. Shared Access: Owner & Partner (Dashboard, Laporan Finansial, Biaya, Modal, Rencana)
        Route::middleware('role:owner,partner')->group(function () {
            Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
            Route::get('/reports/profit-loss', [ReportController::class, 'profitLoss']);
            Route::get('/reports/cash-flow', [ReportController::class, 'cashFlow']);
            Route::get('/expenses', [ExpenseController::class, 'index']);
            Route::get('/expenses/{expense}', [ExpenseController::class, 'show']);
            Route::get('/capital', [CapitalEntryController::class, 'index']);
            Route::get('/capital/{capitalEntry}', [CapitalEntryController::class, 'show']);
            Route::get('/plans', [PlanController::class, 'index']);
            Route::get('/plans/{plan}', [PlanController::class, 'show']);
        });

        // 3. Exclusive Access: Owner Only (CRUD Produk, Restock, Opname, Void, Pengeluaran, Modal, Target, User Management)
        Route::middleware('role:owner')->group(function () {
            // Category CRUD
            Route::post('/categories', [CategoryController::class, 'store']);
            Route::put('/categories/{category}', [CategoryController::class, 'update']);
            Route::patch('/categories/{category}', [CategoryController::class, 'update']);
            Route::delete('/categories/{category}', [CategoryController::class, 'destroy']);

            // Product CRUD, Restock, & Stock Opname
            Route::post('/products', [ProductController::class, 'store']);
            Route::put('/products/{product}', [ProductController::class, 'update']);
            Route::patch('/products/{product}', [ProductController::class, 'update']);
            Route::delete('/products/{product}', [ProductController::class, 'destroy']);
            Route::post('/products/{product}/restock', [ProductController::class, 'restock']);
            Route::post('/products/restock-by-barcode', [ProductController::class, 'restockByBarcode']);
            Route::post('/products/{product}/adjust', [ProductController::class, 'adjustStock']);
            Route::post('/products/{product}/stock', [ProductController::class, 'adjustStock']);

            // Void Completed Transaction
            Route::post('/transactions/{transaction}/void', [TransactionController::class, 'void']);

            // Expenses Create & Void
            Route::post('/expenses', [ExpenseController::class, 'store']);
            Route::post('/expenses/{expense}/void', [ExpenseController::class, 'void']);

            // Capital Management
            Route::post('/capital', [CapitalEntryController::class, 'store']);
            Route::delete('/capital/{capitalEntry}', [CapitalEntryController::class, 'destroy']);

            // Plans (Rencana Usaha) CRUD
            Route::post('/plans', [PlanController::class, 'store']);
            Route::put('/plans/{plan}', [PlanController::class, 'update']);
            Route::patch('/plans/{plan}', [PlanController::class, 'update']);
            Route::delete('/plans/{plan}', [PlanController::class, 'destroy']);

            // User Management (Kasir & Mitra - FR-01 s/d FR-04)
            Route::get('/users', [UserController::class, 'index']);
            Route::post('/users', [UserController::class, 'store']);
            Route::get('/users/{user}', [UserController::class, 'show']);
            Route::put('/users/{user}', [UserController::class, 'update']);
            Route::patch('/users/{user}', [UserController::class, 'update']);
            Route::post('/users/{user}/toggle-status', [UserController::class, 'toggleStatus']);
        });
    });
});
