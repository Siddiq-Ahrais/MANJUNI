<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use App\Models\TransactionItem;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class TransactionController extends Controller
{
    public function index(Request $request)
    {
        $businessId = $request->user()->business_id;
        $perPage = min((int) $request->input('per_page', 20), 100);

        $query = Transaction::where('business_id', $businessId)
            ->when($request->filled('date'), function ($q) use ($request) {
                $q->whereDate('transaction_date', $request->date('date'));
            })
            ->when($request->filled('date_from'), function ($q) use ($request) {
                $q->where('transaction_date', '>=', Carbon::parse($request->input('date_from'))->startOfDay());
            })
            ->when($request->filled('date_to'), function ($q) use ($request) {
                $q->where('transaction_date', '<=', Carbon::parse($request->input('date_to'))->endOfDay());
            })
            ->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->input('status'));
            })
            ->when($request->filled('payment_method'), function ($q) use ($request) {
                $q->where('payment_method', $request->input('payment_method'));
            })
            ->when($request->filled('search'), function ($q) use ($request) {
                $search = $request->string('search');
                $q->where(function ($sub) use ($search) {
                    $sub->where('id', 'like', "%{$search}%")
                        ->orWhere('note', 'like', "%{$search}%")
                        ->orWhere('payment_reference', 'like', "%{$search}%")
                        ->orWhereHas('items.product', function ($pQuery) use ($search) {
                            $pQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('barcode', 'like', "%{$search}%");
                        });
                });
            })
            ->with(['items.product', 'user:id,name,role', 'voidedBy:id,name'])
            ->latest('transaction_date')
            ->latest('id');

        return response()->json($query->paginate($perPage));
    }

    public function show(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        return response()->json($transaction->load(['items.product', 'user:id,name,role', 'voidedBy:id,name']));
    }

    public function store(Request $request)
    {
        $businessId = $request->user()->business_id;

        $data = $request->validate([
            'payment_method' => ['required', 'in:cash,qris,transfer,other'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string', 'max:1000'],
            'transaction_date' => ['nullable', 'date', 'before_or_equal:now'],
            'items' => ['required_without:direct_amount', 'array', 'min:1'],
            'items.*.product_id' => ['required_with:items', 'integer'],
            'items.*.quantity' => ['required_with:items', 'integer', 'min:1'],
            'direct_amount' => ['nullable', 'integer', 'min:1'],
            'service_name' => ['nullable', 'string', 'max:255'],
        ]);

        $transactionDate = ! empty($data['transaction_date'])
            ? Carbon::parse($data['transaction_date'])
            : now();

        $transaction = DB::transaction(function () use ($data, $businessId, $transactionDate, $request) {
            $transaction = Transaction::create([
                'business_id' => $businessId,
                'user_id' => $request->user()->id,
                'transaction_date' => $transactionDate,
                'total_amount' => 0,
                'payment_method' => $data['payment_method'],
                'payment_reference' => $data['payment_reference'] ?? null,
                'note' => $data['note'] ?? null,
                'status' => 'pending',
            ]);

            $total = 0;

            if (! empty($data['items'])) {
                foreach ($data['items'] as $item) {
                    $product = Product::where('business_id', $businessId)
                        ->whereKey($item['product_id'])
                        ->where('is_active', true)
                        ->first();

                    if (! $product) {
                        throw ValidationException::withMessages([
                            'items' => ["Produk ID {$item['product_id']} tidak ditemukan pada usaha ini."],
                        ]);
                    }

                    $subtotal = $item['quantity'] * $product->selling_price;
                    $transaction->items()->create([
                        'product_id' => $product->id,
                        'item_name' => $product->name,
                        'quantity' => $item['quantity'],
                        'unit_price' => $product->selling_price,
                        'cost_price' => $product->cost_price,
                        'subtotal' => $subtotal,
                    ]);
                    $total += $subtotal;
                }
            } elseif (! empty($data['direct_amount'])) {
                $total = (int) $data['direct_amount'];
                $transaction->items()->create([
                    'product_id' => null,
                    'item_name' => $data['service_name'] ?? 'Penjualan Langsung / Layanan',
                    'quantity' => 1,
                    'unit_price' => $total,
                    'cost_price' => 0,
                    'subtotal' => $total,
                ]);
            }

            $transaction->update(['total_amount' => $total]);

            return $transaction;
        });

        return response()->json($transaction->load(['items.product', 'user:id,name']), 201);
    }

    public function confirm(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        $data = $request->validate([
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'payment_method' => ['nullable', 'in:cash,qris,transfer,other'],
        ]);

        $transaction = DB::transaction(function () use ($transaction, $data, $request) {
            $transaction->load('items');

            if ($transaction->status !== 'pending') {
                throw ValidationException::withMessages([
                    'status' => ['Hanya transaksi pending yang dapat dikonfirmasi.'],
                ]);
            }

            foreach ($transaction->items as $item) {
                if (! $item->product_id) {
                    continue;
                }

                $product = Product::whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                if ($product->stock < $item->quantity) {
                    throw ValidationException::withMessages([
                        'items' => ["Stok {$product->name} tidak mencukupi (sisa: {$product->stock}, diminta: {$item->quantity})."],
                    ]);
                }

                $stockAfter = $product->stock - $item->quantity;
                $product->decrement('stock', $item->quantity);

                StockMovement::create([
                    'product_id' => $product->id,
                    'user_id' => $request->user()->id,
                    'transaction_item_id' => $item->id,
                    'type' => 'sale',
                    'quantity_change' => -$item->quantity,
                    'stock_after' => $stockAfter,
                    'note' => "Penjualan transaksi #{$transaction->id}",
                ]);
            }

            $updates = [
                'status' => 'completed',
                'paid_at' => now(),
            ];

            if (! empty($data['payment_reference'])) {
                $updates['payment_reference'] = $data['payment_reference'];
            }
            if (! empty($data['payment_method'])) {
                $updates['payment_method'] = $data['payment_method'];
            }

            $transaction->update($updates);

            return $transaction->fresh(['items.product', 'user:id,name']);
        });

        return response()->json($transaction);
    }

    public function cancel(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        if ($transaction->status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => ['Hanya transaksi berstatus pending yang dapat dibatalkan.'],
            ]);
        }

        $transaction->update([
            'status' => 'cancelled',
            'note' => ($transaction->note ? $transaction->note . ' | ' : '') . 'Dibatalkan oleh kasir/pengguna',
        ]);

        return response()->json($transaction->fresh(['items.product', 'user:id,name']));
    }

    public function void(Request $request, Transaction $transaction)
    {
        abort_unless($transaction->business_id === $request->user()->business_id, 404);

        $data = $request->validate([
            'void_reason' => ['required', 'string', 'max:500'],
        ]);

        if ($transaction->status !== 'completed') {
            throw ValidationException::withMessages([
                'status' => ['Hanya transaksi yang sudah lunas (completed) yang dapat di-void.'],
            ]);
        }

        $transaction = DB::transaction(function () use ($transaction, $data, $request) {
            $transaction->load('items');

            foreach ($transaction->items as $item) {
                if (! $item->product_id) {
                    continue;
                }

                $product = Product::whereKey($item->product_id)->lockForUpdate()->firstOrFail();
                $stockAfter = $product->stock + $item->quantity;
                $product->increment('stock', $item->quantity);

                StockMovement::create([
                    'product_id' => $product->id,
                    'user_id' => $request->user()->id,
                    'transaction_item_id' => $item->id,
                    'type' => 'void_return',
                    'quantity_change' => $item->quantity,
                    'stock_after' => $stockAfter,
                    'note' => "Void transaksi #{$transaction->id}: {$data['void_reason']}",
                ]);
            }

            $transaction->update([
                'status' => 'void',
                'void_reason' => $data['void_reason'],
                'voided_by' => $request->user()->id,
                'voided_at' => now(),
            ]);

            return $transaction->fresh(['items.product', 'user:id,name', 'voidedBy:id,name']);
        });

        return response()->json($transaction);
    }

    public function reset(Request $request)
    {
        $businessId = $request->user()->business_id;

        $deletedCount = DB::transaction(function () use ($businessId) {
            $txIds = Transaction::where('business_id', $businessId)->pluck('id');
            if ($txIds->isEmpty()) {
                return 0;
            }

            $itemIds = TransactionItem::whereIn('transaction_id', $txIds)->pluck('id');
            if ($itemIds->isNotEmpty()) {
                StockMovement::whereIn('transaction_item_id', $itemIds)
                    ->update(['transaction_item_id' => null]);
                TransactionItem::whereIn('id', $itemIds)->delete();
            }

            return Transaction::whereIn('id', $txIds)->delete();
        });

        return response()->json([
            'message' => 'Riwayat transaksi berhasil dikosongkan.',
            'deleted' => $deletedCount,
        ]);
    }
}
