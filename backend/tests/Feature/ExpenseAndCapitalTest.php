<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\CapitalEntry;
use App\Models\Expense;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpenseAndCapitalTest extends TestCase
{
    use RefreshDatabase;

    private Business $business;
    private User $owner;
    private User $cashier;
    private User $partner;

    protected function setUp(): void
    {
        parent::setUp();

        $this->business = Business::create(['name' => 'Usaha Majunih']);
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

    public function test_owner_can_manage_expenses_and_void(): void
    {
        // 1. Owner creates expense
        $res = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/expenses', [
            'category' => 'Listrik dan air',
            'amount' => 350000,
            'note' => 'PLN bulan ini',
        ])->assertCreated();

        $expenseId = $res->json('id');
        $this->assertDatabaseHas('expenses', [
            'id' => $expenseId,
            'amount' => 350000,
            'status' => 'completed',
        ]);

        // 2. Cashier cannot create expense
        $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/expenses', [
            'category' => 'Gaji',
            'amount' => 1000000,
        ])->assertForbidden();

        // 3. Owner voids expense
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/expenses/{$expenseId}/void", [
            'void_reason' => 'Salah nominal',
        ])->assertOk()->assertJsonPath('expense.status', 'void');
    }

    public function test_capital_management_and_partner_read_access(): void
    {
        // 1. Owner creates initial capital and addition
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/capital', [
            'type' => 'initial',
            'amount' => 10000000,
            'source_name' => 'Owner Modal',
        ])->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/capital', [
            'type' => 'addition',
            'amount' => 5000000,
            'source_name' => 'Mitra B',
        ])->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/capital', [
            'type' => 'withdrawal',
            'amount' => 2000000,
            'source_name' => 'Tarik Profit',
        ])->assertCreated();

        // 2. Partner views capital summary
        $summaryRes = $this->actingAs($this->partner, 'sanctum')
            ->getJson('/api/v1/capital')
            ->assertOk();

        $summaryRes->assertJsonPath('summary.total_initial', 10000000)
            ->assertJsonPath('summary.total_addition', 5000000)
            ->assertJsonPath('summary.total_in', 15000000)
            ->assertJsonPath('summary.total_withdrawal', 2000000)
            ->assertJsonPath('summary.net_capital', 13000000);

        // 3. Partner cannot create capital
        $this->actingAs($this->partner, 'sanctum')->postJson('/api/v1/capital', [
            'type' => 'addition',
            'amount' => 1000000,
        ])->assertForbidden();
    }

    public function test_owner_can_crud_business_plans(): void
    {
        $res = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/plans', [
            'title' => 'Renovasi Bar Kopi',
            'target_amount' => 15000000,
            'status' => 'planned',
        ])->assertCreated();

        $planId = $res->json('id');

        $this->actingAs($this->owner, 'sanctum')->putJson("/api/v1/plans/{$planId}", [
            'status' => 'in_progress',
        ])->assertOk()->assertJsonPath('status', 'in_progress');

        $this->actingAs($this->owner, 'sanctum')->deleteJson("/api/v1/plans/{$planId}")
            ->assertOk();

        $this->assertDatabaseMissing('plans', ['id' => $planId]);
    }
}
