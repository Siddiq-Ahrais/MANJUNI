<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ExpenseController extends Controller
{
    public function index(Request $request)
    {
        $perPage = min((int) $request->input('per_page', 20), 100);

        $expenses = Expense::where('business_id', $request->user()->business_id)
            ->when($request->filled('category'), function ($query) use ($request) {
                $query->where('category', $request->string('category'));
            })
            ->when($request->filled('date'), function ($query) use ($request) {
                $query->whereDate('expense_date', $request->date('date'));
            })
            ->when($request->filled('status'), function ($query) use ($request) {
                $query->where('status', $request->string('status'));
            })
            ->with('user:id,name')
            ->latest('expense_date')
            ->paginate($perPage);

        return response()->json($expenses);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'expense_date' => ['nullable', 'date'],
            'category'     => ['required', 'string', 'max:100'],
            'amount'       => ['required', 'integer', 'min:1'],
            'note'         => ['nullable', 'string', 'max:255'],
        ]);

        $expense = Expense::create([
            'business_id'  => $request->user()->business_id,
            'user_id'      => $request->user()->id,
            'expense_date' => $data['expense_date'] ?? now()->toDateString(),
            'category'     => $data['category'],
            'amount'       => $data['amount'],
            'note'         => $data['note'] ?? null,
            'status'       => 'completed',
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
                'status' => ['Pengeluaran sudah pernah dibatalkan sebelumnya.'],
            ]);
        }

        $data = $request->validate([
            'void_reason' => ['required', 'string', 'max:255'],
        ]);

        $expense->update([
            'status'      => 'void',
            'void_reason' => $data['void_reason'],
        ]);

        return response()->json([
            'message' => 'Pengeluaran berhasil dibatalkan (void).',
            'expense' => $expense,
        ]);
    }
}
