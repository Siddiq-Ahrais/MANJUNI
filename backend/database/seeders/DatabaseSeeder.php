<?php

namespace Database\Seeders;

use App\Models\Business;
use App\Models\CapitalEntry;
use App\Models\Category;
use App\Models\Expense;
use App\Models\Plan;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Profil Usaha (FR-01)
        $business = Business::create([
            'name' => 'MAJUNIH Coffee & Snack',
            'address' => 'Jl. Pemuda No. 45, Rawamangun, Jakarta Timur',
            'phone' => '081234567890',
        ]);

        // 2. Akun Berdasarkan Peran (FR-01, FR-02, FR-03, Section 12)
        $password = Hash::make('password123');

        $owner = User::create([
            'business_id' => $business->id,
            'name' => 'Ahmad Pemilik',
            'email' => 'owner@manjuni.id',
            'password' => $password,
            'role' => 'owner',
            'is_active' => true,
        ]);

        $cashier = User::create([
            'business_id' => $business->id,
            'name' => 'Budi Kasir',
            'email' => 'kasir@manjuni.id',
            'password' => $password,
            'role' => 'cashier',
            'is_active' => true,
        ]);

        $partner = User::create([
            'business_id' => $business->id,
            'name' => 'Siti Mitra',
            'email' => 'mitra@manjuni.id',
            'password' => $password,
            'role' => 'partner',
            'is_active' => true,
        ]);

        // 3. Kategori Produk (FR-06)
        $catKopi = Category::create(['business_id' => $business->id, 'name' => 'Minuman Kopi']);
        $catNonKopi = Category::create(['business_id' => $business->id, 'name' => 'Minuman Non-Kopi']);
        $catSnack = Category::create(['business_id' => $business->id, 'name' => 'Makanan Ringan']);
        $catFood = Category::create(['business_id' => $business->id, 'name' => 'Makanan Berat']);

        // 4. Produk & Barcode (FR-05, FR-24, FR-27, 5.7)
        $productsData = [
            [
                'category_id' => $catKopi->id,
                'name' => 'Kopi Susu Gula Aren',
                'barcode' => '8991002105431',
                'unit' => 'cup',
                'cost_price' => 7000,
                'selling_price' => 15000,
                'stock' => 45,
                'min_stock' => 10,
            ],
            [
                'category_id' => $catKopi->id,
                'name' => 'Americano Dingin',
                'barcode' => '8991002105432',
                'unit' => 'cup',
                'cost_price' => 5000,
                'selling_price' => 12000,
                'stock' => 30,
                'min_stock' => 5,
            ],
            [
                'category_id' => $catNonKopi->id,
                'name' => 'Matcha Latte',
                'barcode' => '8992753123456',
                'unit' => 'cup',
                'cost_price' => 9000,
                'selling_price' => 18000,
                'stock' => 3, // Peringatan stok menipis (stock <= min_stock)
                'min_stock' => 5,
            ],
            [
                'category_id' => $catSnack->id,
                'name' => 'Croissant Cokelat',
                'barcode' => '8993005128901',
                'unit' => 'pcs',
                'cost_price' => 10000,
                'selling_price' => 17000,
                'stock' => 4, // Peringatan stok menipis
                'min_stock' => 5,
            ],
            [
                'category_id' => $catSnack->id,
                'name' => 'Kentang Goreng Crispy',
                'barcode' => '8995507113344',
                'unit' => 'porsi',
                'cost_price' => 6000,
                'selling_price' => 13000,
                'stock' => 20,
                'min_stock' => 5,
            ],
            [
                'category_id' => $catFood->id,
                'name' => 'Nasi Goreng Spesial MAJUNIH',
                'barcode' => '8994506112233',
                'unit' => 'porsi',
                'cost_price' => 12000,
                'selling_price' => 22000,
                'stock' => 25,
                'min_stock' => 5,
            ],
        ];

        $createdProducts = [];
        foreach ($productsData as $item) {
            $prod = Product::create(array_merge($item, [
                'business_id' => $business->id,
                'is_active' => true,
            ]));

            StockMovement::create([
                'product_id' => $prod->id,
                'user_id' => $owner->id,
                'type' => 'restock',
                'quantity_change' => $prod->stock,
                'stock_after' => $prod->stock,
                'note' => 'Stok awal pembukaan usaha',
            ]);

            $createdProducts[$prod->barcode] = $prod;
        }

        // 5. Entri Modal (FR-16)
        CapitalEntry::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'entry_date' => Carbon::now()->subDays(30)->toDateString(),
            'type' => 'initial',
            'amount' => 15000000,
            'source_name' => 'Ahmad Pemilik',
            'note' => 'Modal awal pendirian MAJUNIH Coffee',
        ]);

        CapitalEntry::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'entry_date' => Carbon::now()->subDays(15)->toDateString(),
            'type' => 'addition',
            'amount' => 5000000,
            'source_name' => 'Siti Mitra',
            'note' => 'Tambahan modal ekspansi alat & bahan',
        ]);

        // 6. Beban Operasional (FR-12)
        Expense::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'expense_date' => Carbon::now()->subDays(20)->toDateString(),
            'category' => 'Bahan baku',
            'amount' => 1250000,
            'note' => 'Pembelian biji kopi arabika & susu UHT kartonan',
            'status' => 'completed',
        ]);

        Expense::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'expense_date' => Carbon::now()->subDays(10)->toDateString(),
            'category' => 'Listrik dan air',
            'amount' => 450000,
            'note' => 'Tagihan listrik PLN & air PDAM',
            'status' => 'completed',
        ]);

        Expense::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'expense_date' => Carbon::now()->subDays(5)->toDateString(),
            'category' => 'Gaji',
            'amount' => 1500000,
            'note' => 'Gaji paruh waktu kasir & barista',
            'status' => 'completed',
        ]);

        // 7. Transaksi Penjualan Historis (Completed)
        $pastDates = [
            ['days_ago' => 6, 'method' => 'cash', 'qty' => 3, 'prod' => '8991002105431'],
            ['days_ago' => 5, 'method' => 'qris', 'ref' => 'QRIS20261102001', 'qty' => 2, 'prod' => '8991002105432'],
            ['days_ago' => 4, 'method' => 'transfer', 'qty' => 4, 'prod' => '8994506112233'],
            ['days_ago' => 3, 'method' => 'qris', 'ref' => 'QRIS20261104005', 'qty' => 5, 'prod' => '8991002105431'],
            ['days_ago' => 2, 'method' => 'cash', 'qty' => 2, 'prod' => '8995507113344'],
            ['days_ago' => 1, 'method' => 'qris', 'ref' => 'QRIS20261106009', 'qty' => 3, 'prod' => '8991002105431'],
            ['days_ago' => 0, 'method' => 'cash', 'qty' => 2, 'prod' => '8991002105431'],
            ['days_ago' => 0, 'method' => 'qris', 'ref' => 'QRIS20261107012', 'qty' => 1, 'prod' => '8994506112233'],
        ];

        foreach ($pastDates as $idx => $tData) {
            $product = $createdProducts[$tData['prod']];
            $tDate = Carbon::now()->subDays($tData['days_ago'])->setHour(10 + ($idx % 8))->setMinute(15);
            $qty = $tData['qty'];
            $subtotal = $qty * $product->selling_price;

            $tx = Transaction::create([
                'business_id' => $business->id,
                'user_id' => $cashier->id,
                'transaction_date' => $tDate,
                'total_amount' => $subtotal,
                'payment_method' => $tData['method'],
                'payment_reference' => $tData['ref'] ?? null,
                'note' => 'Penjualan kasir',
                'status' => 'completed',
                'paid_at' => (clone $tDate)->addMinutes(2),
            ]);

            $txItem = $tx->items()->create([
                'product_id' => $product->id,
                'item_name' => $product->name,
                'quantity' => $qty,
                'unit_price' => $product->selling_price,
                'cost_price' => $product->cost_price,
                'subtotal' => $subtotal,
            ]);

            StockMovement::create([
                'product_id' => $product->id,
                'user_id' => $cashier->id,
                'transaction_item_id' => $txItem->id,
                'type' => 'sale',
                'quantity_change' => -$qty,
                'stock_after' => $product->stock,
                'note' => "Penjualan transaksi #{$tx->id}",
            ]);
        }

        // 8. Transaksi Berstatus PENDING untuk Live Demo Scan Barcode & Konfirmasi (Fitur Unggulan v1.1)
        $demoPendingProd = $createdProducts['8991002105431'];
        $pendingTx = Transaction::create([
            'business_id' => $business->id,
            'user_id' => $cashier->id,
            'transaction_date' => Carbon::now(),
            'total_amount' => $demoPendingProd->selling_price * 2,
            'payment_method' => 'qris',
            'payment_reference' => 'SHOPEE-QRIS-99128',
            'note' => 'Menunggu konfirmasi kasir setelah cek aplikasi merchant',
            'status' => 'pending',
            'paid_at' => null,
        ]);

        $pendingTx->items()->create([
            'product_id' => $demoPendingProd->id,
            'item_name' => $demoPendingProd->name,
            'quantity' => 2,
            'unit_price' => $demoPendingProd->selling_price,
            'cost_price' => $demoPendingProd->cost_price,
            'subtotal' => $demoPendingProd->selling_price * 2,
        ]);

        // 9. Rencana Usaha (FR-17)
        Plan::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'title' => 'Pengadaan Mesin Espresso 2-Group',
            'description' => 'Upgrade mesin kopi untuk mempercepat waktu pembuatan saat antrean jam makan siang.',
            'due_date' => Carbon::now()->addMonth()->toDateString(),
            'target_amount' => 25000000,
            'status' => 'in_progress',
        ]);

        Plan::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'title' => 'Buka Cabang Kedua di Tebet',
            'description' => 'Mencari lokasi strategis dekat stasiun Tebet untuk konsep grab-and-go.',
            'due_date' => Carbon::now()->addMonths(4)->toDateString(),
            'target_amount' => 50000000,
            'status' => 'planned',
        ]);

        Plan::create([
            'business_id' => $business->id,
            'user_id' => $owner->id,
            'title' => 'Peluncuran Menu Pastry Baru',
            'description' => 'Bekerja sama dengan produsen kue lokal untuk memasok Croissant dan Cinnamon Roll.',
            'due_date' => Carbon::now()->subWeeks(2)->toDateString(),
            'target_amount' => 3000000,
            'status' => 'done',
        ]);
    }
}
