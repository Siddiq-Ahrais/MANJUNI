<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $perPage = min((int) $request->input('per_page', 20), 100);

        $products = Product::where('business_id', $request->user()->business_id)
            ->when($request->filled('category_id'), function ($query) use ($request) {
                $query->where('category_id', $request->integer('category_id'));
            })
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->string('search');
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('barcode', $search);
                });
            })
            ->when($request->boolean('low_stock'), function ($query) {
                $query->whereColumn('stock', '<=', 'min_stock');
            })
            ->when(! ($request->user()->role === 'owner' && $request->boolean('include_inactive')), function ($query) {
                $query->where('is_active', true);
            })
            ->with('category')
            ->latest()
            ->paginate($perPage);

        return response()->json($products);
    }

    public function show(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        return response()->json($product->load('category'));
    }

    public function showByBarcode(Request $request, string $barcode)
    {
        $product = Product::where('business_id', $request->user()->business_id)
            ->where('barcode', $barcode)
            ->where('is_active', true)
            ->with('category')
            ->first();

        if (! $product) {
            return response()->json([
                'message' => 'Produk dengan barcode tersebut tidak ditemukan.',
            ], 404);
        }

        return response()->json($product);
    }

    public function store(Request $request)
    {
        $businessId = $request->user()->business_id;

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'barcode' => [
                'nullable',
                'string',
                'max:100',
                Rule::unique('products', 'barcode')->where('business_id', $businessId),
            ],
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('business_id', $businessId),
            ],
            'unit' => ['required', 'string', 'max:50'],
            'cost_price' => ['required', 'integer', 'min:0'],
            'selling_price' => ['required', 'integer', 'min:0'],
            'stock' => ['nullable', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $product = DB::transaction(function () use ($data, $businessId, $request) {
            $initialStock = $data['stock'] ?? 0;

            $product = Product::create([
                'business_id' => $businessId,
                'category_id' => $data['category_id'] ?? null,
                'name' => $data['name'],
                'barcode' => $data['barcode'] ?? null,
                'unit' => $data['unit'],
                'cost_price' => $data['cost_price'],
                'selling_price' => $data['selling_price'],
                'stock' => $initialStock,
                'min_stock' => $data['min_stock'] ?? 0,
                'is_active' => $data['is_active'] ?? true,
            ]);

            if ($initialStock > 0) {
                StockMovement::create([
                    'product_id' => $product->id,
                    'user_id' => $request->user()->id,
                    'type' => 'restock',
                    'quantity_change' => $initialStock,
                    'stock_after' => $initialStock,
                    'note' => 'Stok awal produk baru',
                ]);
            }

            return $product;
        });

        return response()->json($product->load('category'), 201);
    }

    public function update(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        $businessId = $request->user()->business_id;

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'barcode' => [
                'nullable',
                'string',
                'max:100',
                Rule::unique('products', 'barcode')
                    ->where('business_id', $businessId)
                    ->ignore($product->id),
            ],
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('business_id', $businessId),
            ],
            'unit' => ['sometimes', 'required', 'string', 'max:50'],
            'cost_price' => ['sometimes', 'required', 'integer', 'min:0'],
            'selling_price' => ['sometimes', 'required', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $product->update($data);

        return response()->json($product->fresh('category'));
    }

    public function destroy(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        $product->delete();

        return response()->json(['message' => 'Produk berhasil dihapus.']);
    }

    public function restock(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        $data = $request->validate([
            'quantity' => ['required', 'integer', 'min:1'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $product = DB::transaction(function () use ($product, $data, $request) {
            $lockedProduct = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();
            $lockedProduct->stock += $data['quantity'];
            $lockedProduct->save();

            StockMovement::create([
                'product_id' => $lockedProduct->id,
                'user_id' => $request->user()->id,
                'type' => 'restock',
                'quantity_change' => $data['quantity'],
                'stock_after' => $lockedProduct->stock,
                'note' => $data['note'] ?? 'Restock barang masuk',
            ]);

            return $lockedProduct;
        });

        return response()->json([
            'message' => 'Restock berhasil.',
            'product' => $product->load('category'),
        ]);
    }

    public function restockByBarcode(Request $request)
    {
        $data = $request->validate([
            'barcode' => ['required', 'string'],
            'quantity' => ['required', 'integer', 'min:1'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $product = Product::where('business_id', $request->user()->business_id)
            ->where('barcode', $data['barcode'])
            ->where('is_active', true)
            ->first();

        if (! $product) {
            return response()->json([
                'message' => 'Produk dengan barcode tersebut tidak ditemukan.',
            ], 404);
        }

        $product = DB::transaction(function () use ($product, $data, $request) {
            $lockedProduct = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();
            $lockedProduct->stock += $data['quantity'];
            $lockedProduct->save();

            StockMovement::create([
                'product_id' => $lockedProduct->id,
                'user_id' => $request->user()->id,
                'type' => 'restock',
                'quantity_change' => $data['quantity'],
                'stock_after' => $lockedProduct->stock,
                'note' => $data['note'] ?? 'Restock lewat scan barcode',
            ]);

            return $lockedProduct;
        });

        return response()->json([
            'message' => 'Restock berhasil.',
            'product' => $product->load('category'),
        ]);
    }

    public function adjustStock(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        if ($request->has('actual_stock')) {
            $data = $request->validate([
                'actual_stock' => ['required', 'integer', 'min:0'],
                'note' => ['required', 'string', 'max:500'],
            ]);

            $product = DB::transaction(function () use ($product, $data, $request) {
                $lockedProduct = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();
                $oldStock = $lockedProduct->stock;
                $newStock = $data['actual_stock'];
                $diff = $newStock - $oldStock;

                $lockedProduct->stock = $newStock;
                $lockedProduct->save();

                if ($diff !== 0) {
                    StockMovement::create([
                        'product_id' => $lockedProduct->id,
                        'user_id' => $request->user()->id,
                        'type' => 'adjustment',
                        'quantity_change' => $diff,
                        'stock_after' => $newStock,
                        'note' => $data['note'],
                    ]);
                }

                return $lockedProduct;
            });

            return response()->json([
                'message' => 'Penyesuaian stok (stok opname) berhasil.',
                'product' => $product->load('category'),
            ]);
        }

        $data = $request->validate([
            'type' => ['required', 'in:restock,adjustment'],
            'quantity' => ['required', 'integer'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $quantity = $data['quantity'];
        $type = $data['type'];

        if ($type === 'restock' && $quantity <= 0) {
            throw ValidationException::withMessages([
                'quantity' => ['Jumlah restock harus lebih dari 0.'],
            ]);
        }

        $product = DB::transaction(function () use ($product, $data, $request, $type, $quantity) {
            $product = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();

            $change = $quantity;
            $stockAfter = $product->stock + $change;

            if ($stockAfter < 0) {
                throw ValidationException::withMessages([
                    'quantity' => ['Stok akhir tidak boleh kurang dari 0.'],
                ]);
            }

            $product->stock = $stockAfter;
            $product->save();

            StockMovement::create([
                'product_id' => $product->id,
                'user_id' => $request->user()->id,
                'type' => $type,
                'quantity_change' => $change,
                'stock_after' => $stockAfter,
                'note' => $data['note'] ?? match ($type) {
                    'restock' => 'Penambahan stok masuk',
                    'adjustment' => 'Penyesuaian stok opname',
                },
            ]);

            return $product;
        });

        return response()->json([
            'message' => 'Stok berhasil diperbarui.',
            'product' => $product,
        ]);
    }

    public function stockMovements(Request $request, Product $product)
    {
        abort_unless($product->business_id === $request->user()->business_id, 404);

        $movements = StockMovement::where('product_id', $product->id)
            ->with(['user:id,name,role', 'transactionItem'])
            ->latest('id')
            ->paginate($request->integer('per_page', 30));

        return response()->json($movements);
    }
}
