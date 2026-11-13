<?php

namespace Database\Seeders;

use App\Models\Business;
use App\Models\CapitalEntry;
use App\Models\Category;
use App\Models\Plan;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        // 1. Bisnis Utama
        $business = Business::create([
            'name'    => 'Toko Manjuni POS',
            'address' => 'Jl. Merdeka No. 45, Jakarta Selatan',
            'phone'   => '081234567890',
        ]);

        // 2. Akun Pengguna Default (Owner, Kasir, Partner)
        $password = Hash::make('password123');

        $owner = User::create([
            'business_id' => $business->id,
            'name'        => 'Ahmad Zani (Owner)',
            'email'       => 'owner@manjuni.com',
            'password'    => $password,
            'role'        => 'owner',
            'is_active'   => true,
        ]);

        $cashier = User::create([
            'business_id' => $business->id,
            'name'        => 'Siti Aminah (Kasir)',
            'email'       => 'kasir@manjuni.com',
            'password'    => $password,
            'role'        => 'cashier',
            'is_active'   => true,
        ]);

        $partner = User::create([
            'business_id' => $business->id,
            'name'        => 'Raisul & Ferdi (Partner)',
            'email'       => 'partner@manjuni.com',
            'password'    => $password,
            'role'        => 'partner',
            'is_active'   => true,
        ]);

        // 3. Kategori Produk
        $catFood = Category::create(['business_id' => $business->id, 'name' => 'Makanan']);
        $catDrink = Category::create(['business_id' => $business->id, 'name' => 'Minuman']);
        $catSnack = Category::create(['business_id' => $business->id, 'name' => 'Snack & Cemilan']);
        $catGrocery = Category::create(['business_id' => $business->id, 'name' => 'Sembako']);

        // 4. Katalog Produk Siap Scan Barcode di Mobile
        $products = [
            [
                'category_id'   => $catFood->id,
                'name'          => 'Indomie Goreng Spesial',
                'barcode'       => '8998866200225',
                'unit'          => 'bungkus',
                'cost_price'    => 2800,
                'selling_price' => 3500,
                'stock'         => 120,
                'min_stock'     => 15,
            ],
            [
                'category_id'   => $catDrink->id,
                'name'          => 'Kopi Arabika Tubruk',
                'barcode'       => '8991234567890',
                'unit'          => 'cup',
                'cost_price'    => 6000,
                'selling_price' => 15000,
                'stock'         => 50,
                'min_stock'     => 5,
            ],
            [
                'category_id'   => $catDrink->id,
                'name'          => 'Teh Botol Sosro 250ml',
                'barcode'       => '8999999001122',
                'unit'          => 'kotak',
                'cost_price'    => 3500,
                'selling_price' => 5000,
                'stock'         => 60,
                'min_stock'     => 10,
            ],
            [
                'category_id'   => $catSnack->id,
                'name'          => 'Roti Bakar Coklat Keju',
                'barcode'       => '8993344556677',
                'unit'          => 'porsi',
                'cost_price'    => 7000,
                'selling_price' => 14000,
                'stock'         => 30,
                'min_stock'     => 5,
            ],
            [
                'category_id'   => $catGrocery->id,
                'name'          => 'Minyak Goreng Sania 1L',
                'barcode'       => '8997788990011',
                'unit'          => 'pouch',
                'cost_price'    => 14500,
                'selling_price' => 17500,
                'stock'         => 3, // Pemicu notifikasi low stock di dashboard
                'min_stock'     => 5,
            ],
        ];

        $createdProducts = [];
        foreach ($products as $item) {
            $prod = Product::create(array_merge($item, [
                'business_id' => $business->id,
                'is_active'   => true,
            ]));
            $createdProducts[] = $prod;

            StockMovement::create([
                'product_id'      => $prod->id,
                'user_id'         => $owner->id,
                'type'            => 'adjustment',
                'quantity_change' => $prod->stock,
                'stock_after'     => $prod->stock,
                'note'            => 'Stok awal inisialisasi sistem',
            ]);
        }

        // 5. Contoh Transaksi Penjualan Lunas (Completed)
        $sampleTrx = Transaction::create([
            'business_id'       => $business->id,
            'user_id'           => $cashier->id,
            'transaction_date'  => now()->subHours(2),
            'total_amount'      => 20000,
            'payment_method'    => 'cash',
            'payment_reference' => 'CASH:50000:30000',
            'note'              => 'Pembeli bawa uang pas',
            'status'            => 'completed',
            'paid_at'           => now()->subHours(2),
        ]);

        $sampleTrx->items()->create([
            'product_id'  => $createdProducts[1]->id, // Kopi
            'quantity'    => 1,
            'unit_price'  => 15000,
            'cost_price'  => 6000,
            'subtotal'    => 15000,
        ]);
        $sampleTrx->items()->create([
            'product_id'  => $createdProducts[2]->id, // Teh
            'quantity'    => 1,
            'unit_price'  => 5000,
            'cost_price'  => 3500,
            'subtotal'    => 5000,
        ]);

        // 6. Contoh Modal Usaha Awal
        CapitalEntry::create([
            'business_id' => $business->id,
            'user_id'     => $owner->id,
            'entry_date'  => now()->subDays(30),
            'type'        => 'initial',
            'amount'      => 25000000,
            'source_name' => 'Modal Pribadi Owner',
            'note'        => 'Pembelian mesin kopi dan perlengkapan awal toko',
        ]);

        // 7. Contoh Rencana Target Usaha (Plans)
        Plan::create([
            'business_id'   => $business->id,
            'user_id'       => $owner->id,
            'title'         => 'Pengadaan Mesin Grinder Tambahan',
            'description'   => 'Meningkatkan kapasitas seduh kopi saat jam sibuk',
            'due_date'      => now()->addMonths(2),
            'target_amount' => 4500000,
            'status'        => 'in_progress',
        ]);
    }
}
