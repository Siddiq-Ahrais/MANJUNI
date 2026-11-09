<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CapitalEntry;
use Illuminate\Http\Request;

class CapitalEntryController extends Controller
{
    public function index(Request $request)
    {
        $businessId = $request->user()->business_id;

        $entries = CapitalEntry::where('business_id', $businessId)
            ->when($request->filled('type'), function ($query) use ($request) {
                $query->where('type', $request->string('type'));
            })
            ->with('user:id,name')
            ->latest('entry_date')
            ->get();

        $initial = (int) $entries->where('type', 'initial')->sum('amount');
        $addition = (int) $entries->where('type', 'addition')->sum('amount');
        $withdrawal = (int) $entries->where('type', 'withdrawal')->sum('amount');
        $currentCapital = ($initial + $addition) - $withdrawal;

        return response()->json([
            'summary' => [
                'initial_capital'    => $initial,
                'additional_capital' => $addition,
                'total_withdrawal'   => $withdrawal,
                'current_capital'    => $currentCapital,
            ],
            'entries' => $entries,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'entry_date'  => ['required', 'date'],
            'type'        => ['required', 'in:initial,addition,withdrawal'],
            'amount'      => ['required', 'integer', 'min:1'],
            'source_name' => ['nullable', 'string', 'max:100'],
            'note'        => ['nullable', 'string', 'max:255'],
        ]);

        $entry = CapitalEntry::create([
            'business_id' => $request->user()->business_id,
            'user_id'     => $request->user()->id,
            'entry_date'  => $data['entry_date'],
            'type'        => $data['type'],
            'amount'      => $data['amount'],
            'source_name' => $data['source_name'] ?? null,
            'note'        => $data['note'] ?? null,
        ]);

        return response()->json($entry->load('user:id,name'), 201);
    }

    public function destroy(Request $request, CapitalEntry $capitalEntry)
    {
        abort_unless($capitalEntry->business_id === $request->user()->business_id, 404);

        $capitalEntry->delete();

        return response()->json(['message' => 'Catatan modal berhasil dihapus.']);
    }
}
