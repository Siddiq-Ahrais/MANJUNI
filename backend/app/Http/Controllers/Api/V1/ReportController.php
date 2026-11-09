<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CapitalEntry;
use App\Models\Expense;
use App\Models\Transaction;
use App\Models\TransactionItem;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    private function resolveDateRange(Request $request): array
    {
        $period = $request->input('period', 'monthly');

        switch ($period) {
            case 'daily':
                $start = $request->filled('start_date')
                    ? Carbon::parse($request->input('start_date'))->startOfDay()
                    : now()->startOfDay();
                $end = (clone $start)->endOfDay();
                break;

            case 'weekly':
                $start = $request->filled('start_date')
                    ? Carbon::parse($request->input('start_date'))->startOfWeek()
                    : now()->startOfWeek();
                $end = (clone $start)->endOfWeek();
                break;

            case 'custom':
                $start = $request->filled('start_date')
                    ? Carbon::parse($request->input('start_date'))->startOfDay()
                    : now()->startOfMonth();
                $end = $request->filled('end_date')
                    ? Carbon::parse($request->input('end_date'))->endOfDay()
                    : now()->endOfDay();
                break;

            case 'monthly':
            default:
                $start = $request->filled('start_date')
                    ? Carbon::parse($request->input('start_date'))->startOfMonth()
                    : now()->startOfMonth();
                $end = (clone $start)->endOfMonth();
                break;
        }

        return [$start, $end, $period];
    }

    public function profitLoss(Request $request)
    {
        $businessId = $request->user()->business_id;
        [$startDate, $endDate, $period] = $this->resolveDateRange($request);

        // 1. Penjualan Completed
        $transactionsQuery = Transaction::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('transaction_date', [$startDate, $endDate]);

        $revenue = (int) (clone $transactionsQuery)->sum('total_amount');
        $transactionsCount = (clone $transactionsQuery)->count();

        // 2. HPP (Harga Pokok Penjualan)
        $cogs = (int) TransactionItem::whereHas('transaction', function ($q) use ($businessId, $startDate, $endDate) {
            $q->where('business_id', $businessId)
                ->where('status', 'completed')
                ->whereBetween('transaction_date', [$startDate, $endDate]);
        })->sum(DB::raw('quantity * cost_price'));

        // 3. Laba Kotor
        $grossProfit = $revenue - $cogs;

        // 4. Biaya Operasional (Completed only)
        $expensesQuery = Expense::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('expense_date', [$startDate->toDateString(), $endDate->toDateString()]);

        $totalExpenses = (int) (clone $expensesQuery)->sum('amount');

        // Breakdown Beban Operasional per Kategori
        $expenseCategories = Expense::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('expense_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->select('category', DB::raw('SUM(amount) as total'))
            ->groupBy('category')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($row) => [
                'category' => $row->category,
                'total' => (int) $row->total,
                'percentage' => $totalExpenses > 0 ? round(((int) $row->total / $totalExpenses) * 100, 1) : 0,
            ]);

        // 5. Laba Bersih
        $netProfit = $grossProfit - $totalExpenses;

        // 6. Rincian Penjualan Produk pada Periode Ini
        $productBreakdown = TransactionItem::whereHas('transaction', function ($q) use ($businessId, $startDate, $endDate) {
            $q->where('business_id', $businessId)
                ->where('status', 'completed')
                ->whereBetween('transaction_date', [$startDate, $endDate]);
        })
            ->select(
                'product_id',
                'item_name',
                DB::raw('SUM(quantity) as quantity_sold'),
                DB::raw('SUM(subtotal) as total_sales'),
                DB::raw('SUM(quantity * cost_price) as total_cogs'),
                DB::raw('SUM(subtotal - (quantity * cost_price)) as gross_profit')
            )
            ->groupBy('product_id', 'item_name')
            ->orderByDesc('quantity_sold')
            ->get()
            ->map(fn ($row) => [
                'product_id' => $row->product_id,
                'name' => $row->item_name ?? 'Produk Tanpa Nama',
                'quantity_sold' => (int) $row->quantity_sold,
                'total_sales' => (int) $row->total_sales,
                'total_cogs' => (int) $row->total_cogs,
                'gross_profit' => (int) $row->gross_profit,
            ]);

        return response()->json([
            'period' => $period,
            'start_date' => $startDate->toDateString(),
            'end_date' => $endDate->toDateString(),
            'summary' => [
                'transactions_count' => $transactionsCount,
                'revenue' => $revenue,
                'cogs' => $cogs,
                'gross_profit' => $grossProfit,
                'gross_margin_percentage' => $revenue > 0 ? round(($grossProfit / $revenue) * 100, 1) : 0,
                'operational_expenses' => $totalExpenses,
                'net_profit' => $netProfit,
                'net_margin_percentage' => $revenue > 0 ? round(($netProfit / $revenue) * 100, 1) : 0,
            ],
            'expense_categories' => $expenseCategories,
            'product_breakdown' => $productBreakdown,
        ]);
    }

    public function cashFlow(Request $request)
    {
        $businessId = $request->user()->business_id;
        [$startDate, $endDate, $period] = $this->resolveDateRange($request);

        // 1. Arus Kas Masuk dari Penjualan (Hanya Completed)
        $salesMethods = Transaction::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('transaction_date', [$startDate, $endDate])
            ->select('payment_method', DB::raw('SUM(total_amount) as total'))
            ->groupBy('payment_method')
            ->pluck('total', 'payment_method');

        $salesCash = (int) ($salesMethods['cash'] ?? 0);
        $salesQris = (int) ($salesMethods['qris'] ?? 0);
        $salesTransfer = (int) ($salesMethods['transfer'] ?? 0);
        $salesOther = (int) ($salesMethods['other'] ?? 0);
        $totalSalesCashIn = $salesCash + $salesQris + $salesTransfer + $salesOther;

        // 2. Arus Kas Masuk dari Modal (Initial + Addition)
        $capitalIn = (int) CapitalEntry::where('business_id', $businessId)
            ->whereIn('type', ['initial', 'addition'])
            ->whereBetween('entry_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->sum('amount');

        $totalCashIn = $totalSalesCashIn + $capitalIn;

        // 3. Arus Kas Keluar dari Beban Operasional (Completed)
        $operationalExpenses = (int) Expense::where('business_id', $businessId)
            ->where('status', 'completed')
            ->whereBetween('expense_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->sum('amount');

        // 4. Arus Kas Keluar dari Penarikan Modal
        $capitalWithdrawal = (int) CapitalEntry::where('business_id', $businessId)
            ->where('type', 'withdrawal')
            ->whereBetween('entry_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->sum('amount');

        $totalCashOut = $operationalExpenses + $capitalWithdrawal;

        // 5. Arus Kas Bersih
        $netCashFlow = $totalCashIn - $totalCashOut;

        return response()->json([
            'period' => $period,
            'start_date' => $startDate->toDateString(),
            'end_date' => $endDate->toDateString(),
            'cash_in' => [
                'sales_by_payment_method' => [
                    'cash' => $salesCash,
                    'qris' => $salesQris,
                    'transfer' => $salesTransfer,
                    'other' => $salesOther,
                ],
                'total_sales' => $totalSalesCashIn,
                'capital_entries' => $capitalIn,
                'total_cash_in' => $totalCashIn,
            ],
            'cash_out' => [
                'operational_expenses' => $operationalExpenses,
                'capital_withdrawals' => $capitalWithdrawal,
                'total_cash_out' => $totalCashOut,
            ],
            'net_cash_flow' => $netCashFlow,
        ]);
    }
}
