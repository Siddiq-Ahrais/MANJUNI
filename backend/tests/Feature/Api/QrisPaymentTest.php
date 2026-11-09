<?php

namespace Tests\Feature\Api;

use App\Models\Business;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use App\Services\MidtransService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery\MockInterface;
use Tests\TestCase;

class QrisPaymentTest extends TestCase
{
    use RefreshDatabase;

    public function test_cashier_can_generate_qris_for_pending_transaction(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi Robusta',
            'unit' => 'cup',
            'cost_price' => 5000,
            'selling_price' => 15000,
            'stock' => 10,
        ]);

        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 15000,
            'payment_method' => 'qris',
            'status' => 'pending',
        ]);
        $transaction->items()->create([
            'product_id' => $product->id,
            'quantity' => 1,
            'unit_price' => 15000,
            'cost_price' => 5000,
            'subtotal' => 15000,
        ]);

        $this->mock(MidtransService::class, function (MockInterface $mock) use ($transaction) {
            $mock->shouldReceive('generateQris')
                ->once()
                ->with(\Mockery::on(fn ($trx) => $trx->id === $transaction->id))
                ->andReturn([
                    'order_id' => 'TRX-' . $transaction->id . '-12345678',
                    'transaction_id' => 'midtrans-trx-001',
                    'gross_amount' => 15000,
                    'qr_string' => '00020101021226680016ID.CO.SHOPEE.WWW01189360091800000000005204599953033605802ID5912TOKO MANJUNI6007JAKARTA61051234062070703A016304ABCD',
                    'qr_url' => 'https://api.sandbox.midtrans.com/v2/qris/12345678/qr-code',
                    'expires_at' => now()->addMinutes(15)->toIso8601String(),
                    'status' => 'pending',
                ]);
        });

        $response = $this->actingAs($cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$transaction->id}/qris");

        $response->assertOk()
            ->assertJsonPath('transaction_id', $transaction->id)
            ->assertJsonPath('payment_method', 'qris')
            ->assertJsonStructure([
                'transaction_id',
                'payment_method',
                'qris' => [
                    'order_id',
                    'transaction_id',
                    'gross_amount',
                    'qr_string',
                    'qr_url',
                    'expires_at',
                    'status',
                ],
            ]);
    }

    public function test_midtrans_webhook_completes_transaction_and_decrements_stock(): void
    {
        config(['services.midtrans.server_key' => 'dummy-server-key']);

        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi Robusta',
            'unit' => 'cup',
            'cost_price' => 5000,
            'selling_price' => 15000,
            'stock' => 10,
        ]);

        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 15000,
            'payment_method' => 'qris',
            'status' => 'pending',
        ]);
        $orderId = 'TRX-' . $transaction->id . '-12345678';
        $transaction->update(['payment_reference' => $orderId]);

        $item = $transaction->items()->create([
            'product_id' => $product->id,
            'quantity' => 2,
            'unit_price' => 15000,
            'cost_price' => 5000,
            'subtotal' => 30000,
        ]);

        $statusCode = '200';
        $grossAmount = '15000.00';
        $signatureKey = hash('sha512', $orderId . $statusCode . $grossAmount . 'dummy-server-key');

        $response = $this->postJson('/api/v1/payments/midtrans/webhook', [
            'order_id' => $orderId,
            'status_code' => $statusCode,
            'gross_amount' => $grossAmount,
            'signature_key' => $signatureKey,
            'transaction_status' => 'settlement',
            'payment_type' => 'qris',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('transaction_status', 'completed');

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'status' => 'completed',
            'payment_reference' => $orderId,
        ]);

        // Stock must be decremented by 2
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 8,
        ]);

        // StockMovement must be logged
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'type' => 'sale',
            'quantity_change' => -2,
            'stock_after' => 8,
        ]);

        // Second call (idempotent): must return OK and stock remains 8 (not decremented again)
        $secondResponse = $this->postJson('/api/v1/webhook/midtrans', [
            'order_id' => $orderId,
            'status_code' => $statusCode,
            'gross_amount' => $grossAmount,
            'signature_key' => $signatureKey,
            'transaction_status' => 'settlement',
            'payment_type' => 'qris',
        ]);

        $secondResponse->assertOk()
            ->assertJsonPath('status', 'ok');

        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 8,
        ]);
    }

    public function test_midtrans_webhook_rejects_invalid_signature(): void
    {
        config(['services.midtrans.server_key' => 'dummy-server-key']);

        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $orderId = 'TRX-1-12345';
        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 10000,
            'payment_method' => 'qris',
            'payment_reference' => $orderId,
            'status' => 'pending',
        ]);

        $response = $this->postJson('/api/v1/payments/midtrans/webhook', [
            'order_id' => $orderId,
            'status_code' => '200',
            'gross_amount' => '10000.00',
            'signature_key' => 'invalid-signature-key',
            'transaction_status' => 'settlement',
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('status', 'bad request');
    }

    public function test_cashier_can_check_transaction_status(): void
    {
        $business = Business::create(['name' => 'Toko Manjuni']);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
        ]);
        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 20000,
            'payment_method' => 'qris',
            'payment_reference' => 'TRX-1-999',
            'status' => 'completed',
            'paid_at' => now(),
        ]);

        $response = $this->actingAs($cashier, 'sanctum')
            ->getJson("/api/v1/transactions/{$transaction->id}/status");

        $response->assertOk()
            ->assertJson([
                'transaction_id' => $transaction->id,
                'status' => 'completed',
                'payment_method' => 'qris',
                'payment_reference' => 'TRX-1-999',
                'total_amount' => 20000,
            ]);
    }
}
