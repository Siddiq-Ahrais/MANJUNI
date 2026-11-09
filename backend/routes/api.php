<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CapitalController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\ExpenseController;
use App\Http\Controllers\Api\V1\PlanController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\UserController;

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

    // Authenticated Routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/profile', [AuthController::class, 'profile']);
        Route::post('/auth/password', [AuthController::class, 'updatePassword']);
        Route::get('/user', fn (Request $request) => $request->user()->load('business'));

        // 1. Shared Access: Owner & Cashier (Products read, Barcode scan, Cashier transactions)
        Route::middleware('role:owner,cashier')->group(function () {
            // Products Read & Barcode
            Route::get('/products', [ProductController::class, 'index']);
            Route::get('/products/barcode/{barcode}', [ProductController::class, 'showByBarcode']);
            Route::get('/products/{product}', [ProductController::class, 'show']);
            Route::get('/products/{product}/stock-movements', [ProductController::class, 'stockMovements']);

            // Categories Read
            Route::get('/categories', [CategoryController::class, 'index']);
            Route::get('/categories/{category}', [CategoryController::class, 'show']);

            // Transactions (Kasir & Pemilik)
            Route::get('/transactions', [TransactionController::class, 'index']);
            Route::post('/transactions', [TransactionController::class, 'store']);
            Route::get('/transactions/{transaction}', [TransactionController::class, 'show']);
            Route::post('/transactions/{transaction}/confirm', [TransactionController::class, 'confirm']);
            Route::post('/transactions/{transaction}/cancel', [TransactionController::class, 'cancel']);
        });

        // 2. Shared Access: Owner & Partner (Dashboard, Reports, Capital summary)
        Route::middleware('role:owner,partner')->group(function () {
            Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
            Route::get('/reports/profit-loss', [ReportController::class, 'profitLoss']);
            Route::get('/reports/cash-flow', [ReportController::class, 'cashFlow']);
            Route::get('/capital', [CapitalController::class, 'index']);
            Route::get('/capital/{capitalEntry}', [CapitalController::class, 'show']);
        });

        // 3. Exclusive Access: Owner Only
        Route::middleware('role:owner')->group(function () {
            // Product CRUD, Restock, Stock Opname
            Route::post('/products', [ProductController::class, 'store']);
            Route::put('/products/{product}', [ProductController::class, 'update']);
            Route::patch('/products/{product}', [ProductController::class, 'update']);
            Route::delete('/products/{product}', [ProductController::class, 'destroy']);
            Route::post('/products/{product}/restock', [ProductController::class, 'restock']);
            Route::post('/products/restock-by-barcode', [ProductController::class, 'restockByBarcode']);
            Route::post('/products/{product}/adjust', [ProductController::class, 'adjustStock']);

            // Category CRUD
            Route::post('/categories', [CategoryController::class, 'store']);
            Route::put('/categories/{category}', [CategoryController::class, 'update']);
            Route::patch('/categories/{category}', [CategoryController::class, 'update']);
            Route::delete('/categories/{category}', [CategoryController::class, 'destroy']);

            // Void Completed Transaction
            Route::post('/transactions/{transaction}/void', [TransactionController::class, 'void']);

            // Expenses CRUD & Void
            Route::get('/expenses', [ExpenseController::class, 'index']);
            Route::post('/expenses', [ExpenseController::class, 'store']);
            Route::get('/expenses/{expense}', [ExpenseController::class, 'show']);
            Route::post('/expenses/{expense}/void', [ExpenseController::class, 'void']);

            // Capital Management
            Route::post('/capital', [CapitalController::class, 'store']);
            Route::delete('/capital/{capitalEntry}', [CapitalController::class, 'destroy']);

            // Plans (Rencana Usaha) CRUD
            Route::apiResource('plans', PlanController::class);

            // User Management (Kasir & Mitra)
            Route::get('/users', [UserController::class, 'index']);
            Route::post('/users', [UserController::class, 'store']);
            Route::get('/users/{user}', [UserController::class, 'show']);
            Route::put('/users/{user}', [UserController::class, 'update']);
            Route::patch('/users/{user}', [UserController::class, 'update']);
            Route::post('/users/{user}/toggle-status', [UserController::class, 'toggleStatus']);
        });
    });
});
