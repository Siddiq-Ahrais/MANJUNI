<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserManagementTest extends TestCase
{
    use RefreshDatabase;

    private Business $business;
    private User $owner;
    private User $cashier;

    protected function setUp(): void
    {
        parent::setUp();

        $this->business = Business::create(['name' => 'Kedai Kopi']);
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
    }

    public function test_owner_can_create_cashier_and_partner_accounts(): void
    {
        $res = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/users', [
            'name' => 'Doni Kasir Baru',
            'email' => 'doni@example.com',
            'password' => 'password123',
            'role' => 'cashier',
        ])->assertCreated();

        $this->assertDatabaseHas('users', [
            'email' => 'doni@example.com',
            'role' => 'cashier',
            'business_id' => $this->business->id,
        ]);
    }

    public function test_owner_can_toggle_user_status_but_cannot_deactivate_self(): void
    {
        // Toggle cashier status to inactive
        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/users/{$this->cashier->id}/toggle-status")
            ->assertOk();

        $this->assertFalse($this->cashier->fresh()->is_active);

        // Owner trying to deactivate self must be rejected
        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/users/{$this->owner->id}/toggle-status")
            ->assertStatus(422);

        $this->assertTrue($this->owner->fresh()->is_active);
    }

    public function test_cashier_cannot_access_user_management(): void
    {
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/users')
            ->assertForbidden();

        $this->actingAs($this->cashier, 'sanctum')
            ->postJson('/api/v1/users', [
                'name' => 'Test',
                'email' => 'test@example.com',
                'password' => 'secret123',
                'role' => 'cashier',
            ])
            ->assertForbidden();
    }
}
