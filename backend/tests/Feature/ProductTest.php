<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    private Business $business;
    private User $owner;
    private User $cashier;
    private User $partner;

    protected function setUp(): void
    {
        parent::setUp();

        $this->business = Business::create(['name' => 'Usaha Utama']);
        $this->owner = User::factory()->create([
            'business_id' => $this->business->id,
            'role' => 'owner',
            'is_active' => true,
        ]);
        $this->cashier = User::factory()->create([
            'business_id' => $this->business->id,
            'role' => 'cashier',
            'is_active' => true,
        ]);
        $this->partner = User::factory()->create([
            'business_id' => $this->business->id,
            'role' => 'partner',
            'is_active' => true,
        ]);
    }

    public function test_owner_can_create_category_and_product_with_initial_stock(): void
    {
        // 1. Create Category
        $catRes = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/categories', [
            'name' => 'Minuman',
        ])->assertCreated();

        $categoryId = $catRes->json('id');

        // 2. Create Product
        $prodRes = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', [
            'name' => 'Es Kopi Gula Aren',
            'category_id' => $categoryId,
            'barcode' => '8991234567890',
            'unit' => 'cup',
            'cost_price' => 7000,
            'selling_price' => 15000,
            'stock' => 50,
            'min_stock' => 10,
        ])->assertCreated();

        $productId = $prodRes->json('id');

        $this->assertDatabaseHas('products', [
            'id' => $productId,
            'name' => 'Es Kopi Gula Aren',
            'stock' => 50,
            'barcode' => '8991234567890',
        ]);

        // Stock movement recorded for initial stock
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $productId,
            'type' => 'restock',
            'quantity_change' => 50,
            'stock_after' => 50,
        ]);
    }

    public function test_cashier_can_search_product_by_barcode_and_name(): void
    {
        $product = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Roti Bakar Cokelat',
            'barcode' => '8999998887771',
            'unit' => 'porsi',
            'cost_price' => 5000,
            'selling_price' => 12000,
            'stock' => 20,
            'min_stock' => 5,
            'is_active' => true,
        ]);

        // Search by barcode directly
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/products/barcode/8999998887771')
            ->assertOk()
            ->assertJsonPath('name', 'Roti Bakar Cokelat');

        // Non-existent barcode returns 404
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/products/barcode/0000000000000')
            ->assertNotFound()
            ->assertJsonPath('message', 'Produk dengan barcode tersebut tidak ditemukan.');

        // Search query param
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/products?search=Bakar')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Roti Bakar Cokelat');
    }

    public function test_owner_can_restock_and_adjust_stock_with_movements(): void
    {
        $product = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Teh Manis',
            'barcode' => '8991112223334',
            'unit' => 'gelas',
            'cost_price' => 2000,
            'selling_price' => 5000,
            'stock' => 10,
            'min_stock' => 5,
            'is_active' => true,
        ]);

        // Restock by ID
        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/restock", [
                'quantity' => 15,
                'note' => 'Barang masuk tambahan',
            ])
            ->assertOk();

        $this->assertEquals(25, $product->fresh()->stock);

        // Restock by Barcode (FR-26)
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/products/restock-by-barcode', [
                'barcode' => '8991112223334',
                'quantity' => 10,
                'note' => 'Restock scan barcode',
            ])
            ->assertOk();

        $this->assertEquals(35, $product->fresh()->stock);

        // Stock Opname / Penyesuaian Stok (FR-09, FR-31)
        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/adjust", [
                'actual_stock' => 32,
                'note' => 'Stok fisik tersisa 32, 3 gelas tumpah',
            ])
            ->assertOk();

        $this->assertEquals(32, $product->fresh()->stock);

        // Check movements history
        $movementsRes = $this->actingAs($this->owner, 'sanctum')
            ->getJson("/api/v1/products/{$product->id}/stock-movements")
            ->assertOk();

        $this->assertCount(3, $movementsRes->json('data'));
    }

    public function test_cashier_and_partner_cannot_modify_products(): void
    {
        $product = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Mie Instan',
            'unit' => 'bungkus',
            'cost_price' => 2500,
            'selling_price' => 5000,
            'stock' => 10,
            'min_stock' => 2,
            'is_active' => true,
        ]);

        // Cashier cannot create product
        $this->actingAs($this->cashier, 'sanctum')
            ->postJson('/api/v1/products', [
                'name' => 'Item Baru',
                'unit' => 'pcs',
                'cost_price' => 1000,
                'selling_price' => 2000,
            ])
            ->assertForbidden();

        // Cashier cannot restock
        $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/products/{$product->id}/restock", ['quantity' => 5])
            ->assertForbidden();

        // Partner cannot access products
        $this->actingAs($this->partner, 'sanctum')
            ->getJson('/api/v1/products')
            ->assertForbidden();
    }

    public function test_tenant_data_isolation(): void
    {
        $otherBusiness = Business::create(['name' => 'Usaha Lain']);
        $otherProduct = Product::create([
            'business_id' => $otherBusiness->id,
            'name' => 'Produk Toko Lain',
            'barcode' => '9999999999999',
            'unit' => 'pcs',
            'cost_price' => 1000,
            'selling_price' => 2000,
            'stock' => 10,
            'min_stock' => 1,
            'is_active' => true,
        ]);

        // Cashier in this business cannot look up product of other business
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/products/barcode/9999999999999')
            ->assertNotFound();

        // Owner in this business cannot update other product
        $this->actingAs($this->owner, 'sanctum')
            ->putJson("/api/v1/products/{$otherProduct->id}", [
                'name' => 'Hacked Name',
            ])
            ->assertNotFound();
    }
}
