<?php

namespace App\Services;

use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use Exception;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Midtrans\Config;
use Midtrans\CoreApi;

class MidtransService
{
    public function __construct()
    {
        Config::$serverKey = config('services.midtrans.server_key');
        Config::$isProduction = (bool) config('services.midtrans.is_production', false);
        Config::$isSanitized = (bool) config('services.midtrans.is_sanitized', true);
        Config::$is3ds = (bool) config('services.midtrans.is_3ds', true);
    }

    /**
     * Generate dynamic QRIS charge via Midtrans Core API.
     */
    public function generateQris(Transaction $transaction): array
    {
        if ($transaction->status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => ['Hanya transaksi berstatus pending yang dapat dibuatkan tagihan QRIS.'],
            ]);
        }

        if ($transaction->total_amount <= 0) {
            throw ValidationException::withMessages([
                'total_amount' => ['Total transaksi harus lebih dari 0 untuk membuat QRIS.'],
            ]);
        }

        $orderId = 'TRX-' . $transaction->id . '-' . time();

        $params = [
            'payment_type' => 'qris',
            'transaction_details' => [
                'order_id' => $orderId,
                'gross_amount' => (int) $transaction->total_amount,
            ],
            'qris' => [
                'acquirer' => 'gopay',
            ],
        ];

        try {
            $response = CoreApi::charge($params);
        } catch (Exception $e) {
            Log::error('Midtrans QRIS Charge Error: ' . $e->getMessage(), [
                'transaction_id' => $transaction->id,
                'params' => $params,
            ]);

            throw ValidationException::withMessages([
                'midtrans' => ['Gagal membuat tagihan QRIS ke Midtrans: ' . $e->getMessage()],
            ]);
        }

        $transaction->update([
            'payment_method' => 'qris',
            'payment_reference' => $orderId,
        ]);

        $qrUrl = null;
        if (! empty($response->actions) && is_array($response->actions)) {
            foreach ($response->actions as $action) {
                if (isset($action->name) && $action->name === 'generate-qr-code') {
                    $qrUrl = $action->url;
                    break;
                }
            }
        }

        return [
            'order_id' => $orderId,
            'transaction_id' => $response->transaction_id ?? null,
            'gross_amount' => (int) $transaction->total_amount,
            'qr_string' => $response->qr_string ?? null,
            'qr_url' => $qrUrl,
            'expires_at' => $response->expiry_time ?? null,
            'status' => $response->transaction_status ?? 'pending',
        ];
    }

    /**
     * Verify signature key received from Midtrans webhook.
     */
    public function verifySignature(string $orderId, string $statusCode, string $grossAmount, string $signatureKey): bool
    {
        $serverKey = config('services.midtrans.server_key');
        if (empty($serverKey)) {
            return false;
        }

        $expectedSignature = hash('sha512', $orderId . $statusCode . $grossAmount . $serverKey);

        return hash_equals($expectedSignature, $signatureKey);
    }

    /**
     * Process webhook notification from Midtrans.
     */
    public function handleNotification(array $payload): Transaction
    {
        $orderId = $payload['order_id'] ?? null;
        $statusCode = (string) ($payload['status_code'] ?? '');
        $grossAmount = (string) ($payload['gross_amount'] ?? '');
        $signatureKey = $payload['signature_key'] ?? '';
        $transactionStatus = $payload['transaction_status'] ?? '';

        if (! $orderId) {
            throw new Exception('Order ID tidak valid pada payload notifikasi.');
        }

        // Verify Midtrans signature
        if (! $this->verifySignature($orderId, $statusCode, $grossAmount, $signatureKey)) {
            throw new Exception('Signature key Midtrans tidak valid.');
        }

        // Find transaction by payment_reference or parse TRX-{id}-...
        $transaction = Transaction::where('payment_reference', $orderId)->first();

        if (! $transaction) {
            // Attempt to parse ID from TRX-{id}-{time}
            if (preg_match('/^TRX-(\d+)-/', $orderId, $matches)) {
                $transaction = Transaction::find($matches[1]);
            }
        }

        if (! $transaction) {
            throw new Exception("Transaksi dengan order ID {$orderId} tidak ditemukan.");
        }

        // If already completed, return immediately (idempotent)
        if ($transaction->status === 'completed') {
            return $transaction;
        }

        // Check Midtrans payment status
        if ($transactionStatus === 'settlement' || $transactionStatus === 'capture') {
            return DB::transaction(function () use ($transaction, $orderId) {
                $transaction->load('items');

                foreach ($transaction->items as $item) {
                    $product = Product::whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                    if ($product->stock >= $item->quantity) {
                        $stockAfter = $product->stock - $item->quantity;
                        $product->decrement('stock', $item->quantity);

                        StockMovement::create([
                            'product_id' => $product->id,
                            'user_id' => $transaction->user_id,
                            'transaction_item_id' => $item->id,
                            'type' => 'sale',
                            'quantity_change' => -$item->quantity,
                            'stock_after' => $stockAfter,
                            'note' => 'Pembayaran QRIS Midtrans: ' . $orderId,
                        ]);
                    }
                }

                $transaction->update([
                    'status' => 'completed',
                    'paid_at' => now(),
                    'payment_reference' => $orderId,
                ]);

                return $transaction->fresh('items.product');
            });
        }

        if (in_array($transactionStatus, ['cancel', 'deny', 'expire'], true)) {
            $transaction->update([
                'status' => 'cancelled',
                'note' => ($transaction->note ? $transaction->note . ' | ' : '') . "Pembayaran gagal ({$transactionStatus})",
            ]);
        }

        return $transaction;
    }
}
