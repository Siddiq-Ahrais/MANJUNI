<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\MidtransService;
use Illuminate\Http\Request;

class QrisController extends Controller
{
    /**
     * Generate dynamic QRIS charge for a pending transaction.
     */
    public function generate(Request $request, Transaction $transaction, MidtransService $gateway)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        $qrisData = $gateway->generateQris($transaction);

        return response()->json([
            'transaction_id' => $transaction->id,
            'payment_method' => 'qris',
            'qris' => $qrisData,
        ]);
    }

    /**
     * Check payment status for the transaction.
     */
    public function status(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        return response()->json([
            'transaction_id' => $transaction->id,
            'status' => $transaction->status,
            'payment_method' => $transaction->payment_method,
            'payment_reference' => $transaction->payment_reference,
            'total_amount' => $transaction->total_amount,
            'paid_at' => $transaction->paid_at,
        ]);
    }
}

