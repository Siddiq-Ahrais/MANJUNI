<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CapitalEntry;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class CapitalController extends Controller
{
    public function index(Request $request)
    {
        $businessId = $request->user()->business_id;

        $baseQuery = CapitalEntry::where('business_id', $businessId);

        $totalInitial = (int) (clone $baseQuery)->where('type', 'initial')->sum('amount');
        $totalAddition = (int) (clone $baseQuery)->where('type', 'addition')->sum('amount');
        $totalWithdrawal = (int) (clone $baseQuery)->where('type', 'withdrawal')->sum('amount');
        $totalIn = $totalInitial + $totalAddition;
        $netCapital = $totalIn - $totalWithdrawal;

        $entriesQuery = CapitalEntry::where('business_id', $businessId)
            ->when($request->filled('date_from'), function ($q) use ($request) {
                $q->where('entry_date', '>=', Carbon::parse($request->input('date_from'))->startOfDay());
            })
            ->when($request->filled('date_to'), function ($q) use ($request) {
                $q->where('entry_date', '<=', Carbon::parse($request->input('date_to'))->endOfDay());
            })
            ->when($request->filled('type'), function ($q) use ($request) {
                $q->where('type', $request->input('type'));
            })
            ->with('user:id,name')
            ->latest('entry_date')
            ->latest('id');

        return response()->json([
            'summary' => [
                'total_initial' => $totalInitial,
                'total_addition' => $totalAddition,
                'total_in' => $totalIn,
                'total_withdrawal' => $totalWithdrawal,
                'net_capital' => $netCapital,
            ],
            'entries' => $entriesQuery->paginate($request->integer('per_page', 20)),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'entry_date' => ['nullable', 'date', 'before_or_equal:today'],
            'type' => ['required', 'in:initial,addition,withdrawal'],
            'amount' => ['required', 'integer', 'min:1'],
            'source_name' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $entry = CapitalEntry::create([
            'business_id' => $request->user()->business_id,
            'user_id' => $request->user()->id,
            'entry_date' => ! empty($data['entry_date']) ? Carbon::parse($data['entry_date']) : now()->toDateString(),
            'type' => $data['type'],
            'amount' => $data['amount'],
            'source_name' => $data['source_name'] ?? null,
            'note' => $data['note'] ?? null,
        ]);

        return response()->json($entry->load('user:id,name'), 201);
    }

    public function show(Request $request, CapitalEntry $capitalEntry)
    {
        abort_unless($capitalEntry->business_id === $request->user()->business_id, 404);

        return response()->json($capitalEntry->load('user:id,name'));
    }

    public function destroy(Request $request, CapitalEntry $capitalEntry)
    {
        abort_unless($capitalEntry->business_id === $request->user()->business_id, 404);

        $capitalEntry->delete();

        return response()->json(['message' => 'Entri modal berhasil dihapus.']);
    }
}
