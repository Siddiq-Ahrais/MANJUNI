<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TransactionTest extends TestCase
{
    use RefreshDatabase;

    private Business $business;
    private User $owner;
    private User $cashier;
    private Product $kopi;
    private Product $snack;

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

        $this->kopi = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Kopi Susu',
            'barcode' => '8991234567890',
            'unit' => 'cup',
            'cost_price' => 5000,
            'selling_price' => 12000,
            'stock' => 10,
            'min_stock' => 2,
            'is_active' => true,
        ]);

        $this->snack = Product::create([
            'business_id' => $this->business->id,
            'name' => 'Donat',
            'barcode' => '8991234567891',
            'unit' => 'pcs',
            'cost_price' => 3000,
            'selling_price' => 7000,
            'stock' => 5,
            'min_stock' => 2,
            'is_active' => true,
        ]);
    }

    public function test_cashier_can_create_pending_sale_without_changing_stock(): void
    {
        $response = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'qris',
            'payment_reference' => 'QRIS-REF-001',
            'note' => 'Meja 5',
            'items' => [
                ['product_id' => $this->kopi->id, 'quantity' => 2],
                ['product_id' => $this->snack->id, 'quantity' => 1],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('total_amount', (12000 * 2) + 7000)
            ->assertJsonPath('payment_reference', 'QRIS-REF-001');

        // Stock must NOT change when transaction is pending (FR-28, Rules)
        $this->assertEquals(10, $this->kopi->fresh()->stock);
        $this->assertEquals(5, $this->snack->fresh()->stock);
    }

    public function test_cashier_can_create_service_sale_with_direct_amount(): void
    {
        // FR-15: Penjualan langsung tanpa memilih produk untuk usaha jasa
        $response = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'direct_amount' => 50000,
            'service_name' => 'Sewa Ruang Meeting 1 Jam',
        ]);

        $response->assertCreated()
            ->assertJsonPath('total_amount', 50000)
            ->assertJsonPath('status', 'pending');
    }

    public function test_confirm_payment_decrements_stock_and_logs_movements(): void
    {
        $createRes = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $this->kopi->id, 'quantity' => 3],
            ],
        ])->assertCreated();

        $txId = $createRes->json('id');

        // Kasir konfirmasi pembayaran (FR-28)
        $confirmRes = $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/confirm", [
                'payment_reference' => 'STRUK-CASH-01',
            ])
            ->assertOk();

        $confirmRes->assertJsonPath('status', 'completed')
            ->assertJsonPath('payment_reference', 'STRUK-CASH-01');

        $this->assertNotNull($confirmRes->json('paid_at'));

        // Stock decremented
        $this->assertEquals(7, $this->kopi->fresh()->stock);

        // Movement logged
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $this->kopi->id,
            'type' => 'sale',
            'quantity_change' => -3,
            'stock_after' => 7,
        ]);
    }

    public function test_confirm_payment_fails_when_stock_insufficient(): void
    {
        // Product has stock = 5
        $createRes = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $this->snack->id, 'quantity' => 4],
            ],
        ])->assertCreated();

        $txId = $createRes->json('id');

        // Someone else bought snacks in between, reducing stock to 2
        $this->snack->update(['stock' => 2]);

        // Confirmation must be rejected (FR-29)
        $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/confirm")
            ->assertStatus(422);

        // Transaction is still pending, stock untouched
        $this->assertEquals(2, $this->snack->fresh()->stock);
        $this->assertEquals('pending', Transaction::find($txId)->status);
    }

    public function test_cashier_can_cancel_pending_sale(): void
    {
        $createRes = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $this->kopi->id, 'quantity' => 2],
            ],
        ])->assertCreated();

        $txId = $createRes->json('id');

        // Batalkan penjualan pending (FR-30)
        $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/cancel")
            ->assertOk()
            ->assertJsonPath('status', 'cancelled');

        // Stock remains 10
        $this->assertEquals(10, $this->kopi->fresh()->stock);
    }

    public function test_owner_can_void_completed_transaction_and_restore_stock(): void
    {
        // 1. Create and confirm sale of 4 cups of kopi
        $createRes = $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $this->kopi->id, 'quantity' => 4],
            ],
        ]);

        $txId = $createRes->json('id');

        $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/confirm")
            ->assertOk();

        $this->assertEquals(6, $this->kopi->fresh()->stock);

        // 2. Kasir coba void -> harus DITOLAK (403)
        $this->actingAs($this->cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/void", [
                'void_reason' => 'Salah input',
            ])
            ->assertForbidden();

        // 3. Pemilik void transaksi lunas (FR-14)
        $voidRes = $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/transactions/{$txId}/void", [
                'void_reason' => 'Pelanggan membatalkan pesanan setelah bayar',
            ])
            ->assertOk();

        $voidRes->assertJsonPath('status', 'void')
            ->assertJsonPath('void_reason', 'Pelanggan membatalkan pesanan setelah bayar');

        // Stock restored from 6 back to 10
        $this->assertEquals(10, $this->kopi->fresh()->stock);

        // Movement logged with void_return
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $this->kopi->id,
            'type' => 'void_return',
            'quantity_change' => 4,
            'stock_after' => 10,
        ]);
    }

    public function test_filter_transaction_history(): void
    {
        // Create 2 transactions
        $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'cash',
            'items' => [['product_id' => $this->kopi->id, 'quantity' => 1]],
        ]);

        $this->actingAs($this->cashier, 'sanctum')->postJson('/api/v1/transactions', [
            'payment_method' => 'qris',
            'items' => [['product_id' => $this->snack->id, 'quantity' => 1]],
        ]);

        $res = $this->actingAs($this->cashier, 'sanctum')
            ->getJson('/api/v1/transactions?payment_method=qris')
            ->assertOk();

        $this->assertCount(1, $res->json('data'));
        $this->assertEquals('qris', $res->json('data.0.payment_method'));
    }
}
