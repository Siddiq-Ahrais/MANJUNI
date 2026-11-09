<?php

namespace Tests\Feature\Api;

use App\Models\Business;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductCrudTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_create_product_with_initial_stock(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);
        $category = Category::create([
            'business_id' => $business->id,
            'name' => 'Kopi',
        ]);

        $response = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/products', [
                'name' => 'Kopi Espresso',
                'barcode' => '8991234567890',
                'category_id' => $category->id,
                'unit' => 'cup',
                'cost_price' => 7000,
                'selling_price' => 18000,
                'stock' => 50,
                'min_stock' => 5,
            ]);

        $response->assertCreated()
            ->assertJsonPath('name', 'Kopi Espresso')
            ->assertJsonPath('stock', 50)
            ->assertJsonPath('selling_price', 18000);

        $this->assertDatabaseHas('products', [
            'business_id' => $business->id,
            'name' => 'Kopi Espresso',
            'stock' => 50,
        ]);

        $this->assertDatabaseHas('stock_movements', [
            'type' => 'restock',
            'quantity_change' => 50,
            'stock_after' => 50,
        ]);
    }

    public function test_cashier_cannot_create_or_delete_product(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Teh Manis',
            'unit' => 'cup',
            'cost_price' => 2000,
            'selling_price' => 5000,
            'stock' => 20,
        ]);

        $this->actingAs($cashier, 'sanctum')
            ->postJson('/api/v1/products', [
                'name' => 'Coba Tambah',
                'unit' => 'pcs',
                'cost_price' => 1000,
                'selling_price' => 2000,
            ])
            ->assertForbidden();

        $this->actingAs($cashier, 'sanctum')
            ->deleteJson("/api/v1/products/{$product->id}")
            ->assertForbidden();
    }

    public function test_owner_can_update_product(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi Tubruk',
            'unit' => 'cup',
            'cost_price' => 3000,
            'selling_price' => 6000,
            'stock' => 10,
        ]);

        $response = $this->actingAs($owner, 'sanctum')
            ->putJson("/api/v1/products/{$product->id}", [
                'selling_price' => 8000,
                'name' => 'Kopi Tubruk Manis',
            ]);

        $response->assertOk()
            ->assertJsonPath('selling_price', 8000)
            ->assertJsonPath('name', 'Kopi Tubruk Manis');

        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'selling_price' => 8000,
        ]);
    }

    public function test_owner_can_restock_and_adjust_product_stock(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Susu Kotak',
            'unit' => 'kotak',
            'cost_price' => 4000,
            'selling_price' => 6000,
            'stock' => 10,
        ]);

        // Restock +15 items
        $response = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/stock", [
                'type' => 'restock',
                'quantity' => 15,
                'note' => 'Belanja dari distributor',
            ]);

        $response->assertOk()
            ->assertJsonPath('product.stock', 25);

        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 25,
        ]);

        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'type' => 'restock',
            'quantity_change' => 15,
            'stock_after' => 25,
        ]);

        // Opname adjustment -2 items (broken/missing)
        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/stock", [
                'type' => 'adjustment',
                'quantity' => -2,
                'note' => 'Bocor saat display',
            ])
            ->assertOk()
            ->assertJsonPath('product.stock', 23);

        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 23,
        ]);

        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'type' => 'adjustment',
            'quantity_change' => -2,
            'stock_after' => 23,
        ]);
    }

    public function test_can_filter_products_by_category(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $catFood = Category::create(['business_id' => $business->id, 'name' => 'Makanan']);
        $catDrink = Category::create(['business_id' => $business->id, 'name' => 'Minuman']);

        Product::create([
            'business_id' => $business->id,
            'category_id' => $catFood->id,
            'name' => 'Roti Bakar',
            'unit' => 'porsi',
            'cost_price' => 5000,
            'selling_price' => 12000,
            'stock' => 5,
        ]);
        Product::create([
            'business_id' => $business->id,
            'category_id' => $catDrink->id,
            'name' => 'Es Teh',
            'unit' => 'cup',
            'cost_price' => 1000,
            'selling_price' => 4000,
            'stock' => 20,
        ]);

        $response = $this->actingAs($cashier, 'sanctum')
            ->getJson("/api/v1/products?category_id={$catDrink->id}");

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Es Teh');
    }
}

