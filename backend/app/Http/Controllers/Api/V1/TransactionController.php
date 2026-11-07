<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class TransactionController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'payment_method' => ['required', 'in:cash,qris,transfer,other'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'distinct'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
        ]);

        $transaction = DB::transaction(function () use ($data, $request) {
            $transaction = Transaction::create([
                'business_id' => $request->user()->business_id,
                'user_id' => $request->user()->id,
                'transaction_date' => now(),
                'total_amount' => 0,
                'payment_method' => $data['payment_method'],
                'payment_reference' => $data['payment_reference'] ?? null,
                'note' => $data['note'] ?? null,
                'status' => 'pending',
            ]);

            $total = 0;
            foreach ($data['items'] as $item) {
                $product = Product::where('business_id', $request->user()->business_id)
                    ->whereKey($item['product_id'])
                    ->where('is_active', true)
                    ->lockForUpdate()
                    ->first();

                if (! $product) {
                    throw ValidationException::withMessages([
                        'items' => ['Produk tidak ditemukan pada usaha ini.'],
                    ]);
                }

                $subtotal = $item['quantity'] * $product->selling_price;
                $transaction->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'unit_price' => $product->selling_price,
                    'cost_price' => $product->cost_price,
                    'subtotal' => $subtotal,
                ]);
                $total += $subtotal;
            }

            $transaction->update(['total_amount' => $total]);

            return $transaction;
        });

        return response()->json($transaction->load('items.product'), 201);
    }

    public function confirm(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        $transaction = DB::transaction(function () use ($transaction, $request) {
            $transaction->load('items');

            if ($transaction->status !== 'pending') {
                throw ValidationException::withMessages([
                    'status' => ['Hanya transaksi pending yang dapat dikonfirmasi.'],
                ]);
            }

            foreach ($transaction->items as $item) {
                $product = Product::whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                if ($product->stock < $item->quantity) {
                    throw ValidationException::withMessages([
                        'items' => ["Stok {$product->name} tidak mencukupi."],
                    ]);
                }

                $product->decrement('stock', $item->quantity);
                StockMovement::create([
                    'product_id' => $product->id,
                    'user_id' => $request->user()->id,
                    'transaction_item_id' => $item->id,
                    'type' => 'sale',
                    'quantity_change' => -$item->quantity,
                    'stock_after' => $product->stock - $item->quantity,
                ]);
            }

            $transaction->update(['status' => 'completed', 'paid_at' => now()]);

            return $transaction->fresh('items.product');
        });

        return response()->json($transaction);
    }
}
