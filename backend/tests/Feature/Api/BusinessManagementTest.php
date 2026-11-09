<?php

namespace Tests\Feature\Api;

use App\Models\Business;
use App\Models\CapitalEntry;
use App\Models\Expense;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BusinessManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_record_and_void_expenses(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);

        $response = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/expenses', [
                'expense_date' => now()->toDateString(),
                'category'     => 'Listrik & Air',
                'amount'       => 250000,
                'note'         => 'Token listrik toko bulan ini',
            ]);

        $response->assertCreated()
            ->assertJsonPath('amount', 250000)
            ->assertJsonPath('status', 'completed');

        $expenseId = $response->json('id');

        // Void expense
        $voidResponse = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/expenses/{$expenseId}/void", [
                'void_reason' => 'Salah input nominal',
            ]);

        $voidResponse->assertOk()
            ->assertJsonPath('expense.status', 'void')
            ->assertJsonPath('expense.void_reason', 'Salah input nominal');
    }

    public function test_owner_can_manage_capital_entries_and_view_summary(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);

        // 1. Modal awal Rp 10.000.000
        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/capital', [
                'entry_date' => now()->toDateString(),
                'type'       => 'initial',
                'amount'     => 10000000,
                'note'       => 'Modal awal pembukaan toko',
            ])->assertCreated();

        // 2. Tambahan modal Rp 5.000.000
        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/capital', [
                'entry_date' => now()->toDateString(),
                'type'       => 'addition',
                'amount'     => 5000000,
                'note'       => 'Setoran modal investor',
            ])->assertCreated();

        // 3. Tarik modal (prive) Rp 2.000.000
        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/capital', [
                'entry_date' => now()->toDateString(),
                'type'       => 'withdrawal',
                'amount'     => 2000000,
                'note'       => 'Tarik modal kebutuhan mendesak',
            ])->assertCreated();

        // Cek kalkulasi ringkasan modal (10jt + 5jt - 2jt = 13jt)
        $summaryResponse = $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/capital');

        $summaryResponse->assertOk()
            ->assertJsonPath('summary.initial_capital', 10000000)
            ->assertJsonPath('summary.additional_capital', 5000000)
            ->assertJsonPath('summary.total_withdrawal', 2000000)
            ->assertJsonPath('summary.current_capital', 13000000);
    }

    public function test_owner_can_manage_business_plans(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $owner = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'owner',
        ]);

        $response = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/plans', [
                'title'         => 'Buka Cabang Baru di Jakarta Barat',
                'target_amount' => 50000000,
                'due_date'      => now()->addMonths(6)->toDateString(),
                'status'        => 'in_progress',
            ]);

        $response->assertCreated()
            ->assertJsonPath('title', 'Buka Cabang Baru di Jakarta Barat')
            ->assertJsonPath('target_amount', 50000000);

        $planId = $response->json('id');

        $updateResponse = $this->actingAs($owner, 'sanctum')
            ->putJson("/api/v1/plans/{$planId}", [
                'status' => 'done',
            ]);

        $updateResponse->assertOk()
            ->assertJsonPath('status', 'done');
    }
}

