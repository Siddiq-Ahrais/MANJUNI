<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    use RefreshDatabase;

    


    public function test_the_application_returns_a_successful_response(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
    }

    public function test_the_api_health_endpoint_returns_ok(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response
            ->assertOk()
            ->assertJson([
                'status' => 'ok',
            ]);
    }

    public function test_a_business_owner_can_register_from_the_mobile_api(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'business_name' => 'Toko Manjuni',
            'name' => 'Owner',
            'email' => 'owner@example.com',
            'password' => 'password123',
        ]);

        $response
            ->assertCreated()
            ->assertJsonStructure(['user', 'business', 'token']);

        $this->assertDatabaseHas('users', [
            'email' => 'owner@example.com',
            'role' => 'owner',
        ]);
    }

    public function test_role_permissions_match_the_mobile_access_matrix(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $partner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'partner',
        ]);

        $this->actingAs($cashier, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertForbidden();

        $this->actingAs($partner, 'sanctum')
            ->getJson('/api/v1/products')
            ->assertForbidden();

        $this->actingAs($partner, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertOk();
    }

    public function test_pending_sale_does_not_change_stock_until_payment_confirmation(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi',
            'unit' => 'pcs',
            'cost_price' => 5000,
            'selling_price' => 8000,
            'stock' => 10,
            'min_stock' => 2,
        ]);

        $pending = $this->actingAs($cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
        ])->assertCreated();

        $this->assertDatabaseHas('products', ['id' => $product->id, 'stock' => 10]);

        $this->actingAs($cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$pending->json('id')}/confirm")
            ->assertOk()
            ->assertJsonPath('status', 'completed');

        $this->assertDatabaseHas('products', ['id' => $product->id, 'stock' => 8]);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity_change' => -2,
            'type' => 'sale',
        ]);
    }

    public function test_sale_rejects_negative_or_zero_quantity(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi',
            'unit' => 'pcs',
            'cost_price' => 5000,
            'selling_price' => 8000,
            'stock' => 10,
        ]);

        $this->actingAs($cashier, 'sanctum')
            ->postJson('/api/v1/transactions', [
                'payment_method' => 'cash',
                'items' => [['product_id' => $product->id, 'quantity' => 0]],
            ])
            ->assertUnprocessable();
    }
}
