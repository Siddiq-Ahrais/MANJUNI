<?php

namespace Tests\Feature\Api;

use App\Models\Business;
use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_create_category(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);

        $response = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/categories', [
                'name' => 'Minuman',
            ]);

        $response->assertCreated()
            ->assertJsonPath('name', 'Minuman');

        $this->assertDatabaseHas('categories', [
            'business_id' => $business->id,
            'name' => 'Minuman',
        ]);
    }

    public function test_cashier_cannot_create_category(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);

        $response = $this->actingAs($cashier, 'sanctum')
            ->postJson('/api/v1/categories', [
                'name' => 'Makanan',
            ]);

        $response->assertForbidden();
    }

    public function test_cashier_and_owner_can_list_categories(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        Category::create(['business_id' => $business->id, 'name' => 'Snack']);
        Category::create(['business_id' => $business->id, 'name' => 'Minuman']);

        $response = $this->actingAs($cashier, 'sanctum')
            ->getJson('/api/v1/categories');

        $response->assertOk()
            ->assertJsonCount(2);
    }

    public function test_owner_can_update_and_delete_category(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);
        $category = Category::create([
            'business_id' => $business->id,
            'name' => 'Lama',
        ]);

        $updateResponse = $this->actingAs($owner, 'sanctum')
            ->putJson("/api/v1/categories/{$category->id}", [
                'name' => 'Baru',
            ]);

        $updateResponse->assertOk()
            ->assertJsonPath('name', 'Baru');

        $deleteResponse = $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/categories/{$category->id}");

        $deleteResponse->assertOk();
        $this->assertDatabaseMissing('categories', ['id' => $category->id]);
    }
}

