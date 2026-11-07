<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = Product::where('business_id', $request->user()->business_id)
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->string('search');
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('barcode', $search);
                });
            })
            ->where('is_active', true)
            ->with('category')
            ->latest()
            ->paginate(20);

        return response()->json($products);
    }

    public function showByBarcode(Request $request, string $barcode)
    {
        $product = Product::where('business_id', $request->user()->business_id)
            ->where('barcode', $barcode)
            ->where('is_active', true)
            ->with('category')
            ->firstOrFail();

        return response()->json($product);
    }
}
