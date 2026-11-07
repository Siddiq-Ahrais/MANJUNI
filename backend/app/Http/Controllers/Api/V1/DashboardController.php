<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function summary(Request $request)
    {
        $businessId = $request->user()->business_id;
        $today = now()->startOfDay();

        $sales = Transaction::where('business_id', $businessId)
            ->where('status', 'completed')
            ->where('transaction_date', '>=', $today);

        $trend = Transaction::selectRaw('DATE(transaction_date) as date, SUM(total_amount) as total')
            ->where('business_id', $businessId)
            ->where('status', 'completed')
            ->where('transaction_date', '>=', now()->subDays(6)->startOfDay())
            ->groupBy(DB::raw('DATE(transaction_date)'))
            ->orderBy('date')
            ->get();

        return response()->json([
            'today' => [
                'transactions' => (clone $sales)->count(),
                'sales' => (int) (clone $sales)->sum('total_amount'),
            ],
            'low_stock_products' => Product::where('business_id', $businessId)
                ->where('is_active', true)
                ->whereColumn('stock', '<=', 'min_stock')
                ->count(),
            'sales_trend' => $trend,
        ]);
    }
}
