<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use Illuminate\Http\Request;

class PlanController extends Controller
{
    public function index(Request $request)
    {
        $plans = Plan::where('business_id', $request->user()->business_id)
            ->when($request->filled('status'), function ($query) use ($request) {
                $query->where('status', $request->string('status'));
            })
            ->with('user:id,name')
            ->latest('due_date')
            ->get();

        return response()->json($plans);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'title'         => ['required', 'string', 'max:255'],
            'description'   => ['nullable', 'string'],
            'due_date'      => ['nullable', 'date'],
            'target_amount' => ['nullable', 'integer', 'min:0'],
            'status'        => ['nullable', 'in:planned,in_progress,done'],
        ]);

        $plan = Plan::create([
            'business_id'   => $request->user()->business_id,
            'user_id'       => $request->user()->id,
            'title'         => $data['title'],
            'description'   => $data['description'] ?? null,
            'due_date'      => $data['due_date'] ?? null,
            'target_amount' => $data['target_amount'] ?? null,
            'status'        => $data['status'] ?? 'planned',
        ]);

        return response()->json($plan->load('user:id,name'), 201);
    }

    public function show(Request $request, Plan $plan)
    {
        abort_unless($plan->business_id === $request->user()->business_id, 404);

        return response()->json($plan->load('user:id,name'));
    }

    public function update(Request $request, Plan $plan)
    {
        abort_unless($plan->business_id === $request->user()->business_id, 404);

        $data = $request->validate([
            'title'         => ['sometimes', 'required', 'string', 'max:255'],
            'description'   => ['nullable', 'string'],
            'due_date'      => ['nullable', 'date'],
            'target_amount' => ['nullable', 'integer', 'min:0'],
            'status'        => ['sometimes', 'required', 'in:planned,in_progress,done'],
        ]);

        $plan->update($data);

        return response()->json($plan->fresh('user:id,name'));
    }

    public function destroy(Request $request, Plan $plan)
    {
        abort_unless($plan->business_id === $request->user()->business_id, 404);

        $plan->delete();

        return response()->json(['message' => 'Rencana target berhasil dihapus.']);
    }
}
