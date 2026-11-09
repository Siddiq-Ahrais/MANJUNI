<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Business;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'business_name' => ['required', 'string', 'max:255'],
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'address' => ['nullable', 'string'],
            'phone' => ['nullable', 'string', 'max:50'],
        ]);

        $result = DB::transaction(function () use ($data) {
            $business = Business::create([
                'name' => $data['business_name'],
                'address' => $data['address'] ?? null,
                'phone' => $data['phone'] ?? null,
            ]);

            $user = User::create([
                'business_id' => $business->id,
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => $data['password'],
                'role' => 'owner',
                'is_active' => true,
            ]);

            return [$business, $user];
        });

        [$business, $user] = $result;

        return response()->json([
            'user' => $user,
            'business' => $business,
            'token' => $user->createToken('mobile')->plainTextToken,
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! $user->is_active || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Email atau password tidak valid.'], 422);
        }

        return response()->json([
            'user' => $user->load('business'),
            'token' => $user->createToken('mobile')->plainTextToken,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logout berhasil.']);
    }

    public function profile(Request $request)
    {
        return response()->json([
            'user' => $request->user()->load('business'),
        ]);
    }

    public function updatePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            return response()->json(['message' => 'Kata sandi saat ini tidak cocok.'], 422);
        }

        $user->update([
            'password' => $data['new_password'],
        ]);

        return response()->json(['message' => 'Kata sandi berhasil diperbarui.']);
    }
}
