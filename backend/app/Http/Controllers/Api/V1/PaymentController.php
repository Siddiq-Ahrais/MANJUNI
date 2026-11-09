<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Midtrans\Config;
use Midtrans\CoreApi;

class PaymentController extends Controller
{
    /**
     * Pembayaran Tunai (Cash) dengan perhitungan otomatis uang diterima & kembalian.
     */
    public function payWithCash(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        if ($transaction->status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => ['Hanya transaksi pending yang dapat dibayarkan.'],
            ]);
        }

        $data = $request->validate([
            'cash_received' => ['required', 'integer', 'min:' . $transaction->total_amount],
            'note'          => ['nullable', 'string', 'max:255'],
        ]);

        $cashReceived = (int) $data['cash_received'];
        $changeAmount = $cashReceived - (int) $transaction->total_amount;

        $transaction = DB::transaction(function () use ($transaction, $request, $cashReceived, $changeAmount, $data) {
            $transaction->load('items');

            // 1. Kurangi stok barang
            foreach ($transaction->items as $item) {
                $product = Product::whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                if ($product->stock < $item->quantity) {
                    throw ValidationException::withMessages([
                        'items' => ["Stok {$product->name} tidak mencukupi."],
                    ]);
                }

                $stockAfter = $product->stock - $item->quantity;
                $product->decrement('stock', $item->quantity);

                StockMovement::create([
                    'product_id'          => $product->id,
                    'user_id'             => $request->user()->id,
                    'transaction_item_id' => $item->id,
                    'type'                => 'sale',
                    'quantity_change'     => -$item->quantity,
                    'stock_after'         => $stockAfter,
                    'note'                => 'Penjualan tunai',
                ]);
            }

            // 2. Tandai transaksi lunas
            $cashNote = 'Diterima: Rp ' . number_format($cashReceived, 0, ',', '.') . ' | Kembalian: Rp ' . number_format($changeAmount, 0, ',', '.');
            $fullNote = trim(($transaction->note ? $transaction->note . ' | ' : '') . ($data['note'] ?? '') . ' (' . $cashNote . ')');

            $transaction->update([
                'status'            => 'completed',
                'payment_method'    => 'cash',
                'payment_reference' => "CASH:{$cashReceived}:{$changeAmount}",
                'paid_at'           => now(),
                'note'              => $fullNote,
            ]);

            return $transaction->fresh(['items.product', 'user', 'business']);
        });

        return response()->json([
            'message'       => 'Pembayaran tunai berhasil.',
            'cash_received' => $cashReceived,
            'change_amount' => $changeAmount,
            'transaction'   => $transaction,
            'receipt'       => $this->buildReceiptData($transaction, $cashReceived, $changeAmount),
        ]);
    }

    /**
     * Pembayaran Transfer Bank / Virtual Account (BCA, BNI, BRI, Mandiri, Permata).
     */
    public function payWithBankTransfer(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        if ($transaction->status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => ['Hanya transaksi pending yang dapat diproses pembayarannya.'],
            ]);
        }

        $data = $request->validate([
            'bank' => ['required', 'in:bca,bni,bri,mandiri,permata,cimb'],
        ]);

        $bank = strtolower($data['bank']);
        $orderId = 'TRX-' . $transaction->id . '-' . time();

        Config::$serverKey = config('services.midtrans.server_key');
        Config::$isProduction = (bool) config('services.midtrans.is_production', false);
        Config::$isSanitized = true;
        Config::$is3ds = true;

        $vaNumber = null;
        $billKey = null;
        $billerCode = null;

        // Coba integrasi Midtrans jika kredensial terpasang
        if (config('services.midtrans.server_key')) {
            try {
                $params = [
                    'payment_type' => $bank === 'mandiri' ? 'echannel' : 'bank_transfer',
                    'transaction_details' => [
                        'order_id'     => $orderId,
                        'gross_amount' => (int) $transaction->total_amount,
                    ],
                ];

                if ($bank === 'mandiri') {
                    $params['echannel'] = [
                        'bill_info1' => 'Payment for:',
                        'bill_info2' => 'Toko Manjuni',
                    ];
                } elseif ($bank === 'permata') {
                    $params['bank_transfer'] = ['bank' => 'permata'];
                } else {
                    $params['bank_transfer'] = ['bank' => $bank];
                }

                $response = CoreApi::charge($params);

                if (isset($response->va_numbers[0]->va_number)) {
                    $vaNumber = $response->va_numbers[0]->va_number;
                } elseif (isset($response->permata_va_number)) {
                    $vaNumber = $response->permata_va_number;
                } elseif (isset($response->bill_key)) {
                    $billKey = $response->bill_key;
                    $billerCode = $response->biller_code;
                }
            } catch (Exception $e) {
                Log::warning('Midtrans Bank Transfer Charge Error: ' . $e->getMessage());
            }
        }

        // Fallback demo/manual Virtual Account jika sandbox belum diisi key
        if (! $vaNumber && ! $billKey) {
            $vaPrefix = match ($bank) {
                'bca' => '1099',
                'bni' => '8808',
                'bri' => '0201',
                default => '9999',
            };
            $vaNumber = $vaPrefix . str_pad((string) $transaction->id, 8, '0', STR_PAD_LEFT);
        }

        $transaction->update([
            'payment_method'    => 'transfer',
            'payment_reference' => $orderId,
        ]);

        return response()->json([
            'transaction_id'    => $transaction->id,
            'payment_method'    => 'transfer',
            'bank'              => strtoupper($bank),
            'order_id'          => $orderId,
            'va_number'         => $vaNumber,
            'bill_key'          => $billKey,
            'biller_code'       => $billerCode,
            'total_amount'      => (int) $transaction->total_amount,
            'instruction'       => "Silakan transfer ke nomor Virtual Account {$vaNumber} sesuai nominal tagihan.",
        ]);
    }

    /**
     * Struk Digital / Payload Cetak Thermal ala Tokopedia / Shopee POS.
     */
    public function getReceipt(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        $transaction->load(['items.product', 'user', 'business']);

        // Ekstrak info tunai jika metode pembayaran cash
        $cashReceived = null;
        $changeAmount = null;

        if ($transaction->payment_reference && str_starts_with($transaction->payment_reference, 'CASH:')) {
            $parts = explode(':', $transaction->payment_reference);
            $cashReceived = isset($parts[1]) ? (int) $parts[1] : null;
            $changeAmount = isset($parts[2]) ? (int) $parts[2] : null;
        }

        return response()->json([
            'receipt' => $this->buildReceiptData($transaction, $cashReceived, $changeAmount),
        ]);
    }

    /**
     * Cek status pembayaran transaksi.
     */
    public function checkStatus(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        return response()->json([
            'transaction_id'    => $transaction->id,
            'status'            => $transaction->status,
            'payment_method'    => $transaction->payment_method,
            'payment_reference' => $transaction->payment_reference,
            'total_amount'      => $transaction->total_amount,
            'paid_at'           => $transaction->paid_at,
        ]);
    }

    /**
     * Helper menyusun struktur data struk belanja standar POS & e-commerce.
     */
    protected function buildReceiptData(Transaction $transaction, ?int $cashReceived = null, ?int $changeAmount = null): array
    {
        $business = $transaction->business;
        $cashier = $transaction->user;

        $items = $transaction->items->map(function ($item) {
            return [
                'product_name' => $item->product->name ?? 'Produk',
                'unit'         => $item->product->unit ?? 'pcs',
                'quantity'     => $item->quantity,
                'unit_price'   => $item->unit_price,
                'subtotal'     => $item->subtotal,
            ];
        });

        return [
            'store' => [
                'name'    => $business->name ?? 'MANJUNI STORE',
                'address' => $business->address ?? 'Indonesia',
                'phone'   => $business->phone ?? '-',
            ],
            'transaction' => [
                'invoice_number' => 'INV-' . $transaction->created_at->format('Ymd') . '-' . str_pad((string) $transaction->id, 5, '0', STR_PAD_LEFT),
                'transaction_id' => $transaction->id,
                'date'           => $transaction->transaction_date->format('d/m/Y H:i'),
                'cashier_name'   => $cashier->name ?? 'Kasir',
            ],
            'items' => $items,
            'payment' => [
                'total_amount'      => $transaction->total_amount,
                'payment_method'    => strtoupper($transaction->payment_method),
                'payment_reference' => $transaction->payment_reference,
                'cash_received'     => $cashReceived,
                'change_amount'     => $changeAmount,
                'status'            => $transaction->status,
                'paid_at'           => $transaction->paid_at ? $transaction->paid_at->format('d/m/Y H:i:s') : null,
            ],
            'footer' => [
                'greeting' => 'Terima kasih telah berbelanja!',
                'notice'   => 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.',
            ],
        ];
    }
}
