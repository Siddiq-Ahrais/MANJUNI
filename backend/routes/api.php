<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\TransactionController;

Route::prefix('v1')->group(function () {
    Route::get('/health', function () {
        return response()->json([
            'status' => 'ok',
        ]);
    });

    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/user', fn (Request $request) => $request->user()->load('business'));
        Route::middleware('role:owner,cashier')->group(function () {
            Route::get('/products', [ProductController::class, 'index']);
            Route::get('/products/barcode/{barcode}', [ProductController::class, 'showByBarcode']);
            Route::post('/transactions', [TransactionController::class, 'store']);
            Route::post('/transactions/{transaction}/confirm', [TransactionController::class, 'confirm']);
        });
        Route::middleware('role:owner,partner')->get('/dashboard/summary', [DashboardController::class, 'summary']);
    });
});
