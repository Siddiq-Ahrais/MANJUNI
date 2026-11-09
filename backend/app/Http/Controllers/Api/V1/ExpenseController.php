<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class ExpenseController extends Controller
{
    public function index(Request $request)
    {
        $businessId = $request->user()->business_id;

        $query = Expense::where('business_id', $businessId)
            ->when($request->filled('date_from'), function ($q) use ($request) {
                $q->where('expense_date', '>=', Carbon::parse($request->input('date_from'))->startOfDay());
            })
            ->when($request->filled('date_to'), function ($q) use ($request) {
                $q->where('expense_date', '<=', Carbon::parse($request->input('date_to'))->endOfDay());
            })
            ->when($request->filled('category'), function ($q) use ($request) {
                $q->where('category', $request->input('category'));
            })
            ->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->input('status'));
            })
            ->with('user:id,name')
            ->latest('expense_date')
            ->latest('id');

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'expense_date' => ['nullable', 'date', 'before_or_equal:today'],
            'category' => ['required', 'string', 'max:100'],
            'amount' => ['required', 'integer', 'min:1'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $expense = Expense::create([
            'business_id' => $request->user()->business_id,
            'user_id' => $request->user()->id,
            'expense_date' => ! empty($data['expense_date']) ? Carbon::parse($data['expense_date']) : now()->toDateString(),
            'category' => $data['category'],
            'amount' => $data['amount'],
            'note' => $data['note'] ?? null,
            'status' => 'completed',
        ]);

        return response()->json($expense->load('user:id,name'), 201);
    }

    public function show(Request $request, Expense $expense)
    {
        abort_unless($expense->business_id === $request->user()->business_id, 404);

        return response()->json($expense->load('user:id,name'));
    }

    public function void(Request $request, Expense $expense)
    {
        abort_unless($expense->business_id === $request->user()->business_id, 404);

        if ($expense->status === 'void') {
            throw ValidationException::withMessages([
                'status' => ['Pengeluaran ini sudah dibatalkan (void).'],
            ]);
        }

        $data = $request->validate([
            'void_reason' => ['required', 'string', 'max:500'],
        ]);

        $expense->update([
            'status' => 'void',
            'void_reason' => $data['void_reason'],
        ]);

        return response()->json([
            'message' => 'Pengeluaran operasional berhasil di-void.',
            'expense' => $expense->fresh('user:id,name'),
        ]);
    }
}
