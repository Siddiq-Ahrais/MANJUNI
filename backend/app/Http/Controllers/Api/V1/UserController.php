<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $users = User::where('business_id', $request->user()->business_id)
            ->orderBy('id')
            ->get();

        return response()->json($users);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'role' => ['required', 'in:cashier,partner'],
        ]);

        $user = User::create([
            'business_id' => $request->user()->business_id,
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            'role' => $data['role'],
            'is_active' => true,
        ]);

        return response()->json($user, 201);
    }

    public function show(Request $request, User $user)
    {
        abort_unless($user->business_id === $request->user()->business_id, 404);

        return response()->json($user);
    }

    public function update(Request $request, User $user)
    {
        abort_unless($user->business_id === $request->user()->business_id, 404);

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => [
                'sometimes',
                'required',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($user->id),
            ],
            'password' => ['nullable', 'string', 'min:8'],
            'role' => ['sometimes', 'required', 'in:cashier,partner'],
            'is_active' => ['sometimes', 'required', 'boolean'],
        ]);

        if ($user->role === 'owner' && isset($data['role']) && $data['role'] !== 'owner') {
            return response()->json(['message' => 'Peran Pemilik tidak dapat diubah.'], 422);
        }

        if ($user->id === $request->user()->id && isset($data['is_active']) && ! $data['is_active']) {
            return response()->json(['message' => 'Anda tidak dapat menonaktifkan akun sendiri.'], 422);
        }

        $user->fill(array_filter([
            'name' => $data['name'] ?? null,
            'email' => $data['email'] ?? null,
            'role' => $data['role'] ?? null,
            'is_active' => $data['is_active'] ?? null,
            'password' => ! empty($data['password']) ? $data['password'] : null,
        ], fn ($val) => $val !== null));

        $user->save();

        return response()->json($user);
    }

    public function toggleStatus(Request $request, User $user)
    {
        abort_unless($user->business_id === $request->user()->business_id, 404);

        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'Anda tidak dapat menonaktifkan akun sendiri.'], 422);
        }

        if ($user->role === 'owner') {
            return response()->json(['message' => 'Akun Pemilik tidak dapat dinonaktifkan.'], 422);
        }

        $user->is_active = ! $user->is_active;
        $user->save();

        return response()->json([
            'message' => 'Status akun berhasil diperbarui.',
            'user' => $user,
        ]);
    }
}
