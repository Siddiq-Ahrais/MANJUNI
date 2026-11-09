<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    public function index(Request $request)
    {
        $categories = Category::where('business_id', $request->user()->business_id)
            ->withCount('products')
            ->orderBy('name')
            ->get();

        return response()->json($categories);
    }

    public function store(Request $request)
    {
        $businessId = $request->user()->business_id;

        $data = $request->validate([
            'name' => [
                'required',
                'string',
                'max:100',
                Rule::unique('categories', 'name')->where('business_id', $businessId),
            ],
        ]);

        $category = Category::create([
            'business_id' => $businessId,
            'name' => $data['name'],
        ]);

        return response()->json($category, 201);
    }

    public function show(Request $request, Category $category)
    {
        abort_unless($category->business_id === $request->user()->business_id, 404);

        return response()->json($category->loadCount('products'));
    }

    public function update(Request $request, Category $category)
    {
        abort_unless($category->business_id === $request->user()->business_id, 404);

        $businessId = $request->user()->business_id;

        $data = $request->validate([
            'name' => [
                'required',
                'string',
                'max:100',
                Rule::unique('categories', 'name')
                    ->where('business_id', $businessId)
                    ->ignore($category->id),
            ],
        ]);

        $category->update(['name' => $data['name']]);

        return response()->json($category);
    }

    public function destroy(Request $request, Category $category)
    {
        abort_unless($category->business_id === $request->user()->business_id, 404);

        $category->delete();

        return response()->json(['message' => 'Kategori berhasil dihapus.']);
    }
}

