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

        // 3. Tren Penjualan 7 Hari Terakhir
        $sevenDaysStart = now()->subDays(6)->startOfDay();
        $trend7Days = Transaction::selectRaw('date(transaction_date) as date, SUM(total_amount) as total, COUNT(*) as count')
            ->where('business_id', $businessId)
            ->where('status', 'completed')
            ->where('transaction_date', '>=', $sevenDaysStart)
            ->groupBy(DB::raw('date(transaction_date)'))
            ->orderBy('date')
            ->get()
            ->map(fn ($row) => [
                'date' => $row->date,
                'total' => (int) $row->total,
                'count' => (int) $row->count,
            ]);

        // 4. Tren Penjualan 30 Hari Terakhir
        $thirtyDaysStart = now()->subDays(29)->startOfDay();
        $trend30Days = Transaction::selectRaw('date(transaction_date) as date, SUM(total_amount) as total, COUNT(*) as count')
            ->where('business_id', $businessId)
            ->where('status', 'completed')
            ->where('transaction_date', '>=', $thirtyDaysStart)
            ->groupBy(DB::raw('date(transaction_date)'))
            ->orderBy('date')
            ->get()
            ->map(fn ($row) => [
                'date' => $row->date,
                'total' => (int) $row->total,
                'count' => (int) $row->count,
            ]);

        // 5. Tren Penjualan Bulanan (6 bulan terakhir)
        $monthSql = $driver === 'sqlite'
            ? "strftime('%Y-%m', transaction_date)"
            : "DATE_FORMAT(transaction_date, '%Y-%m')";

        $sixMonthsStart = now()->subMonths(5)->startOfMonth();
        $trendMonthly = Transaction::selectRaw("{$monthSql} as month, SUM(total_amount) as total, COUNT(*) as count")
            ->where('business_id', $businessId)
            ->where('status', 'completed')
            ->where('transaction_date', '>=', $sixMonthsStart)
            ->groupBy(DB::raw($monthSql))
            ->orderBy('month')
            ->get()
            ->map(fn ($row) => [
                'month' => $row->month,
                'total' => (int) $row->total,
                'count' => (int) $row->count,
            ]);

        // 6. Produk Terlaris (30 hari terakhir)
        $topProducts = TransactionItem::whereHas('transaction', function ($q) use ($businessId, $thirtyDaysStart) {
            $q->where('business_id', $businessId)
                ->where('status', 'completed')
                ->where('transaction_date', '>=', $thirtyDaysStart);
        })
            ->whereNotNull('product_id')
            ->select('product_id', DB::raw('SUM(quantity) as total_sold'), DB::raw('SUM(subtotal) as total_revenue'))
            ->groupBy('product_id')
            ->orderByDesc('total_sold')
            ->limit(5)
            ->with('product:id,name,unit,selling_price')
            ->get()
            ->map(function ($item) {
                return [
                    'product_id' => $item->product_id,
                    'name' => $item->product?->name ?? 'Produk dihapus',
                    'unit' => $item->product?->unit ?? 'pcs',
                    'total_sold' => (int) $item->total_sold,
                    'total_revenue' => (int) $item->total_revenue,
                ];
            });

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
}
