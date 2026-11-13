<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\CapitalEntry;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DashboardAndReportTest extends TestCase
{
    use RefreshDatabase;

    private Business $business;
    private User $owner;
    private User $cashier;
    private User $partner;
    private Product $product;

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
        $this->partner = User::factory()->create([
            'business_id' => $this->business->id,
            'role' => 'partner',
            'is_active' => true,
        ]);

        $this->product = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Kopi Tubruk',
            'unit' => 'cup',
            'cost_price' => 4000,
            'selling_price' => 10000,
            'stock' => 3, // stock <= min_stock
            'min_stock' => 5,
            'is_active' => true,
        ]);
    }

    public function test_dashboard_summary_and_role_access(): void
    {
        // 1. Create a completed sale: 2 cups = 20000 (cost: 8000)
        $tx = Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->cashier->id,
            'transaction_date' => now(),
            'total_amount' => 20000,
            'payment_method' => 'cash',
            'status' => 'completed',
            'paid_at' => now(),
        ]);
        $tx->items()->create([
            'product_id' => $this->product->id,
            'item_name' => $this->product->name,
            'quantity' => 2,
            'unit_price' => 10000,
            'cost_price' => 4000,
            'subtotal' => 20000,
        ]);

        // 2. Create a pending sale (should NOT count in today's sales)
        Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->cashier->id,
            'transaction_date' => now(),
            'total_amount' => 50000,
            'payment_method' => 'qris',
            'status' => 'pending',
        ]);

        // 3. Cashier cannot access dashboard (403)
        $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertForbidden();

        // 4. Partner can access dashboard
        $partnerRes = $this->actingAs($this->partner, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertOk();

        $partnerRes->assertJsonPath('today.sales', 20000)
            ->assertJsonPath('today.transactions', 1)
            ->assertJsonPath('low_stock_products.count', 1);

        // 5. Owner can access dashboard
        $this->actingAs($this->owner, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertOk();
    }

    public function test_profit_and_loss_report(): void
    {
        // Completed Sale: Revenue = 30000, COGS = 12000, Gross Profit = 18000
        $tx = Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'transaction_date' => now(),
            'total_amount' => 30000,
            'payment_method' => 'qris',
            'status' => 'completed',
            'paid_at' => now(),
        ]);
        $tx->items()->create([
            'product_id' => $this->product->id,
            'item_name' => $this->product->name,
            'quantity' => 3,
            'unit_price' => 10000,
            'cost_price' => 4000,
            'subtotal' => 30000,
        ]);

        // Completed Expense = 5000
        Expense::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'expense_date' => now()->toDateString(),
            'category' => 'Bahan baku',
            'amount' => 5000,
            'status' => 'completed',
        ]);

        // Voided Expense = 2000 (must be excluded from report)
        Expense::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'expense_date' => now()->toDateString(),
            'category' => 'Lainnya',
            'amount' => 2000,
            'status' => 'void',
            'void_reason' => 'Batal beli',
        ]);

        // Net Profit = Revenue (30000) - COGS (12000) - Expenses (5000) = 13000
        $reportRes = $this->actingAs($this->partner, 'sanctum')
            ->getJson('/api/v1/reports/profit-loss?period=monthly')
            ->assertOk();

        $reportRes->assertJsonPath('summary.revenue', 30000)
            ->assertJsonPath('summary.cogs', 12000)
            ->assertJsonPath('summary.gross_profit', 18000)
            ->assertJsonPath('summary.operational_expenses', 5000)
            ->assertJsonPath('summary.net_profit', 13000);
    }

    public function test_cash_flow_report(): void
    {
        // 1. Completed Sale (Cash: 25000)
        Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->cashier->id,
            'transaction_date' => now(),
            'total_amount' => 25000,
            'payment_method' => 'cash',
            'status' => 'completed',
            'paid_at' => now(),
        ]);

        // 2. Capital in: 100000
        CapitalEntry::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'entry_date' => now()->toDateString(),
            'type' => 'addition',
            'amount' => 100000,
        ]);

        // 3. Operational expense: 15000
        Expense::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'expense_date' => now()->toDateString(),
            'category' => 'Bahan baku',
            'amount' => 15000,
            'status' => 'completed',
        ]);

        // 4. Capital withdrawal: 20000
        CapitalEntry::create([
            'business_id' => $this->business->id,
            'user_id' => $this->owner->id,
            'entry_date' => now()->toDateString(),
            'type' => 'withdrawal',
            'amount' => 20000,
        ]);

        // Cash In: 25000 + 100000 = 125000
        // Cash Out: 15000 + 20000 = 35000
        // Net Cash Flow = 90000
        $res = $this->actingAs($this->partner, 'sanctum')
            ->getJson('/api/v1/reports/cash-flow?period=monthly')
            ->assertOk();

        $res->assertJsonPath('cash_in.total_cash_in', 125000)
            ->assertJsonPath('cash_out.total_cash_out', 35000)
            ->assertJsonPath('net_cash_flow', 90000);
    }

    public function test_sales_trend_uses_sold_quantity_not_revenue_idr(): void
    {
        $this->travelTo(now()->startOfMonth()->addDays(5)->setHour(12));

        $expensiveProduct = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Paket Mesin Kopi',
            'unit' => 'unit',
            'cost_price' => 300000,
            'selling_price' => 500000,
            'stock' => 10,
            'min_stock' => 1,
            'is_active' => true,
        ]);

        // Kemarin: 1 produk mahal = Rp500.000 (revenue tinggi, sold sedikit = 1)
        $yesterday = now()->subDay();
        $txYesterday = Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->cashier->id,
            'transaction_date' => $yesterday,
            'total_amount' => 500000,
            'payment_method' => 'cash',
            'status' => 'completed',
            'paid_at' => $yesterday,
        ]);
        $txYesterday->items()->create([
            'product_id' => $expensiveProduct->id,
            'item_name' => $expensiveProduct->name,
            'quantity' => 1,
            'unit_price' => 500000,
            'cost_price' => 300000,
            'subtotal' => 500000,
        ]);

        // Hari ini: 6 produk murah = Rp60.000 (revenue lebih rendah, sold terbanyak = 6)
        $today = now();
        $txToday = Transaction::create([
            'business_id' => $this->business->id,
            'user_id' => $this->cashier->id,
            'transaction_date' => $today,
            'total_amount' => 60000,
            'payment_method' => 'qris',
            'status' => 'completed',
            'paid_at' => $today,
        ]);
        $txToday->items()->create([
            'product_id' => $this->product->id,
            'item_name' => $this->product->name,
            'quantity' => 6,
            'unit_price' => 10000,
            'cost_price' => 4000,
            'subtotal' => 60000,
        ]);

        $res = $this->actingAs($this->owner, 'sanctum')
            ->getJson('/api/v1/dashboard/summary')
            ->assertOk();

        $trend7 = collect($res->json('sales_trend.last_7_days'));
        $yesterdayRow = $trend7->firstWhere('date', $yesterday->toDateString());
        $todayRow = $trend7->firstWhere('date', $today->toDateString());

        $this->assertNotNull($yesterdayRow);
        $this->assertNotNull($todayRow);
        $this->assertSame(1, $yesterdayRow['total']);
        $this->assertSame(1, $yesterdayRow['sold']);
        $this->assertSame(500000, $yesterdayRow['revenue']);

        $this->assertSame(6, $todayRow['total']);
        $this->assertSame(6, $todayRow['sold']);
        $this->assertSame(60000, $todayRow['revenue']);
        $this->assertGreaterThan($yesterdayRow['sold'], $todayRow['sold']);

        $monthlyRow = collect($res->json('sales_trend.monthly'))
            ->firstWhere('month', $today->format('Y-m'));
        $this->assertNotNull($monthlyRow);
        $this->assertSame(7, $monthlyRow['sold']);
        $this->assertSame(7, $monthlyRow['total']);
    }
}
