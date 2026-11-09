<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\MidtransService;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class WebhookController extends Controller
{
    /**
     * Handle incoming gateway payment webhook (Idempotent & Verified).
     */
    public function handle(Request $request, MidtransService $gateway)
    {
        $orderId = $request->input('order_id');
        if (! $orderId) {
            return response()->json([
                'status' => 'bad request',
                'message' => 'Order ID tidak ditemukan pada payload webhook.',
            ], 400);
        }

        // Cari transaksi berdasarkan payment_reference atau parsing ID
        $transaction = Transaction::where('payment_reference', $orderId)->first();
        if (! $transaction && preg_match('/^TRX-(\d+)-/', $orderId, $matches)) {
            $transaction = Transaction::find($matches[1]);
        }

        if (! $transaction) {
            return response()->json([
                'status' => 'not found',
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        // Aturan 1 (Idempoten): Jika sudah dibayar/diproses, langsung return OK tanpa proses ulang
        if ($transaction->paid_at || $transaction->status === 'completed') {
            return response()->json([
                'status' => 'ok',
                'message' => 'Transaksi sudah pernah diproses sebelumnya (idempotent).',
            ]);
        }

        // Aturan 2 (Verifikasi ulang & update status): Serahkan ke gateway service
        try {
            $transaction = $gateway->handleNotification($request->all());

            return response()->json([
                'status' => 'ok',
                'message' => 'Webhook berhasil diproses.',
                'transaction_id' => $transaction->id,
                'transaction_status' => $transaction->status,
            ]);
        } catch (Exception $e) {
            Log::warning('Webhook Verification Failed: ' . $e->getMessage(), [
                'payload' => $request->all(),
            ]);

            return response()->json([
                'status' => 'bad request',
                'message' => $e->getMessage(),
            ], 400);
        }
    }
}

