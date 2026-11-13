<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\TransactionItem;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function summary(Request $request)
    {
        $businessId = $request->user()->business_id;
        $driver = DB::connection()->getDriverName();

        $todayStart = now()->startOfDay();
        $todayEnd = now()->endOfDay();
        $monthStart = now()->startOfMonth();
        $monthEnd = now()->endOfDay();

        // 1. Omzet & Transaksi Hari Ini (Hanya Completed)
        $todayTransactions = Transaction::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('transaction_date', [$todayStart, $todayEnd]);

        $todaySales = (int) (clone $todayTransactions)->sum('total_amount');
        $todayCount = (clone $todayTransactions)->count();

        // 2. Peringatan Stok Menipis
        $lowStockQuery = Product::where('business_id', $businessId)
            ->where('is_active', true)
            ->whereColumn('stock', '<=', 'min_stock');

        $lowStockCount = (clone $lowStockQuery)->count();
        $lowStockItems = (clone $lowStockQuery)
            ->select('id', 'name', 'barcode', 'unit', 'stock', 'min_stock')
            ->orderBy('stock')
            ->limit(10)
            ->get();

        // 3. Tren Penjualan Produk 7 Hari Terakhir (jumlah produk terjual per hari)
        $sevenDaysStart = now()->subDays(6)->startOfDay();
        $trend7Days = $this->aggregateSoldTrend(
            $businessId,
            $sevenDaysStart,
            'date(transactions.transaction_date)',
            'date',
        );

        // 4. Tren Penjualan Produk 30 Hari Terakhir (jumlah produk terjual per hari)
        $thirtyDaysStart = now()->subDays(29)->startOfDay();
        $trend30Days = $this->aggregateSoldTrend(
            $businessId,
            $thirtyDaysStart,
            'date(transactions.transaction_date)',
            'date',
        );

        // 5. Tren Penjualan Produk Bulanan (6 bulan terakhir)
        $monthSql = $driver === 'sqlite'
            ? "strftime('%Y-%m', transactions.transaction_date)"
            : "DATE_FORMAT(transactions.transaction_date, '%Y-%m')";

        $sixMonthsStart = now()->subMonths(5)->startOfMonth();
        $trendMonthly = $this->aggregateSoldTrend(
            $businessId,
            $sixMonthsStart,
            $monthSql,
            'month',
        );

        // 6. Produk Terlaris (berdasarkan jumlah produk terjual tertinggi, 30 hari terakhir / semua transaksi)
        $buildTopProductsQuery = function (bool $restrict30Days) use ($businessId, $thirtyDaysStart) {
            return TransactionItem::whereHas('transaction', function ($q) use ($businessId, $thirtyDaysStart, $restrict30Days) {
                $q->where('business_id', $businessId)
                    ->where('status', 'completed');
                if ($restrict30Days) {
                    $q->where('transaction_date', '>=', $thirtyDaysStart);
                }
            })
                ->select(
                    DB::raw('MAX(product_id) as product_id'),
                    DB::raw('MAX(item_name) as fallback_name'),
                    DB::raw('SUM(quantity) as total_sold'),
                    DB::raw('SUM(subtotal) as total_revenue')
                )
                ->groupBy(DB::raw('COALESCE(CAST(product_id AS CHAR), item_name)'))
                ->orderByDesc('total_sold')
                ->orderByDesc('total_revenue')
                ->limit(5)
                ->with('product:id,name,unit,selling_price,category_id', 'product.category:id,name')
                ->get();
        };

        $topProductRows = $buildTopProductsQuery(true);
        if ($topProductRows->isEmpty()) {
            $topProductRows = $buildTopProductsQuery(false);
        }

        $topProducts = $topProductRows->map(function ($item) {
            return [
                'product_id' => $item->product_id,
                'name' => $item->product?->name ?? $item->fallback_name ?? 'Produk Umum',
                'unit' => $item->product?->unit ?? 'pcs',
                'category' => $item->product?->category?->name ?? 'Umum',
                'total_sold' => (int) $item->total_sold,
                'total_revenue' => (int) $item->total_revenue,
            ];
        })->values();

        // 7. Ringkasan Laba Bersih Bulan Berjalan (P1)
        $monthlyRevenue = (int) Transaction::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('transaction_date', [$monthStart, $monthEnd])
            ->sum('total_amount');

        $monthlyCogs = (int) TransactionItem::whereHas('transaction', function ($q) use ($businessId, $monthStart, $monthEnd) {
            $q->where('business_id', $businessId)
                ->where('status', 'completed')
                ->whereBetween('transaction_date', [$monthStart, $monthEnd]);
        })->sum(DB::raw('quantity * cost_price'));

        $monthlyExpenses = (int) Expense::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('expense_date', [$monthStart->toDateString(), $monthEnd->toDateString()])
            ->sum('amount');

        $monthlyGrossProfit = $monthlyRevenue - $monthlyCogs;
        $monthlyNetProfit = $monthlyGrossProfit - $monthlyExpenses;

        return response()->json([
            'today' => [
                'sales' => $todaySales,
                'transactions' => $todayCount,
            ],
            'low_stock_products' => [
                'count' => $lowStockCount,
                'items' => $lowStockItems,
            ],
            'sales_trend' => [
                'last_7_days' => $trend7Days,
                'last_30_days' => $trend30Days,
                'monthly' => $trendMonthly,
            ],
            'top_products' => $topProducts,
            'current_month_summary' => [
                'revenue' => $monthlyRevenue,
                'cogs' => $monthlyCogs,
                'gross_profit' => $monthlyGrossProfit,
                'operational_expenses' => $monthlyExpenses,
                'net_profit' => $monthlyNetProfit,
            ],
        ]);
    }

    /**
     * Hitung total produk terjual (dan pendapatan referensi) per hari/bulan
     * agar grafik tren merefleksikan jumlah produk sold terbanyak.
     */
    private function aggregateSoldTrend(int $businessId, Carbon $startDate, string $groupExpr, string $alias): array
    {
        return TransactionItem::query()
            ->join('transactions', 'transaction_items.transaction_id', '=', 'transactions.id')
            ->where('transactions.business_id', $businessId)
            ->where('transactions.status', 'completed')
            ->where('transactions.transaction_date', '>=', $startDate)
            ->selectRaw("{$groupExpr} as {$alias}, COALESCE(SUM(transaction_items.quantity), 0) as sold, COALESCE(SUM(transaction_items.subtotal), 0) as revenue, COUNT(DISTINCT transactions.id) as count")
            ->groupBy(DB::raw($groupExpr))
            ->orderBy($alias)
            ->get()
            ->map(fn ($row) => [
                $alias => $row->{$alias},
                'total' => (int) $row->sold,
                'sold' => (int) $row->sold,
                'revenue' => (int) $row->revenue,
                'count' => (int) $row->count,
            ])
            ->all();
    }
}
