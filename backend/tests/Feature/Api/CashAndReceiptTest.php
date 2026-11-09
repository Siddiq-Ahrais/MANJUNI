<?php

namespace Tests\Feature\Api;

use App\Models\Business;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CashAndReceiptTest extends TestCase
{
    use RefreshDatabase;

    public function test_cashier_can_pay_with_cash_and_auto_calculate_change(): void
    {
        $business = Business::create([
            'name' => 'Toko Manjuni POS',
            'address' => 'Jl. Merdeka No. 45, Jakarta',
            'phone' => '08123456789',
        ]);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
            'name' => 'Siti Kasir',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Kopi Arabika',
            'unit' => 'cup',
            'cost_price' => 5000,
            'selling_price' => 15000,
            'stock' => 10,
        ]);

        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 30000,
            'payment_method' => 'cash',
            'status' => 'pending',
        ]);
        $transaction->items()->create([
            'product_id' => $product->id,
            'quantity' => 2,
            'unit_price' => 15000,
            'cost_price' => 5000,
            'subtotal' => 30000,
        ]);

        // Pembeli bayar dengan uang 50.000 (total tagihan 30.000 -> kembalian 20.000)
        $response = $this->actingAs($cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$transaction->id}/pay/cash", [
                'cash_received' => 50000,
                'note' => 'Uang pas',
            ]);

        $response->assertOk()
            ->assertJsonPath('cash_received', 50000)
            ->assertJsonPath('change_amount', 20000)
            ->assertJsonPath('transaction.status', 'completed')
            ->assertJsonPath('receipt.store.name', 'Toko Manjuni POS')
            ->assertJsonPath('receipt.payment.change_amount', 20000)
            ->assertJsonStructure([
                'message',
                'cash_received',
                'change_amount',
                'transaction',
                'receipt' => [
                    'store' => ['name', 'address', 'phone'],
                    'transaction' => ['invoice_number', 'transaction_id', 'date', 'cashier_name'],
                    'items',
                    'payment' => ['total_amount', 'payment_method', 'cash_received', 'change_amount', 'status', 'paid_at'],
                    'footer' => ['greeting', 'notice'],
                ],
            ]);

        // Stock berkurang 2
        $this->assertDatabaseHas('products', [
            'id' => $product->id,
            'stock' => 8,
        ]);

        // Stock movement tercatat
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'type' => 'sale',
            'quantity_change' => -2,
            'stock_after' => 8,
        ]);
    }

    public function test_cash_payment_fails_if_received_amount_is_less_than_total(): void
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
            'total_amount' => 50000,
            'payment_method' => 'cash',
            'status' => 'pending',
        ]);

        // Bayar hanya 30.000 padahal tagihan 50.000
        $response = $this->actingAs($cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$transaction->id}/pay/cash", [
                'cash_received' => 30000,
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['cash_received']);
    }

    public function test_cashier_can_pay_with_bank_transfer_va(): void
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
            'total_amount' => 75000,
            'payment_method' => 'transfer',
            'status' => 'pending',
        ]);

        $response = $this->actingAs($cashier, 'sanctum')
            ->postJson("/api/v1/transactions/{$transaction->id}/pay/bank-transfer", [
                'bank' => 'bca',
            ]);

        $response->assertOk()
            ->assertJsonPath('transaction_id', $transaction->id)
            ->assertJsonPath('bank', 'BCA')
            ->assertJsonStructure([
                'transaction_id',
                'payment_method',
                'bank',
                'order_id',
                'va_number',
                'total_amount',
                'instruction',
            ]);
    }

    public function test_can_fetch_receipt_for_completed_transaction(): void
    {
        $business = Business::create([
            'name' => 'Toko Manjuni Mall',
            'address' => 'Lt. 2 No. 12',
            'phone' => '021-998877',
        ]);
        $cashier = User::factory()->create([
            'business_id' => $business->id,
            'role' => 'cashier',
            'name' => 'Budi',
        ]);
        $product = Product::create([
            'business_id' => $business->id,
            'name' => 'Donat Coklat',
            'unit' => 'pcs',
            'cost_price' => 3000,
            'selling_price' => 8000,
            'stock' => 50,
        ]);

        $transaction = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => now(),
            'total_amount' => 16000,
            'payment_method' => 'cash',
            'payment_reference' => 'CASH:20000:4000',
            'status' => 'completed',
            'paid_at' => now(),
        ]);
        $transaction->items()->create([
            'product_id' => $product->id,
            'quantity' => 2,
            'unit_price' => 8000,
            'cost_price' => 3000,
            'subtotal' => 16000,
        ]);

        $response = $this->actingAs($cashier, 'sanctum')
            ->getJson("/api/v1/transactions/{$transaction->id}/receipt");

        $response->assertOk()
            ->assertJsonPath('receipt.store.name', 'Toko Manjuni Mall')
            ->assertJsonPath('receipt.transaction.cashier_name', 'Budi')
            ->assertJsonPath('receipt.payment.total_amount', 16000)
            ->assertJsonPath('receipt.payment.cash_received', 20000)
            ->assertJsonPath('receipt.payment.change_amount', 4000)
            ->assertJsonCount(1, 'receipt.items');
    }
}

