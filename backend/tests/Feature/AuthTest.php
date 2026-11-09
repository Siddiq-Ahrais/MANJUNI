<?php

namespace Tests\Feature;

use App\Models\Business;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_register_with_business_profile(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'business_name' => 'Kopi Maju Bersama',
            'name' => 'Bambang',
            'email' => 'bambang@example.com',
            'password' => 'secret123',
            'address' => 'Jl. Merdeka No. 10',
            'phone' => '081299998888',
        ]);

        $response->assertCreated()
            ->assertJsonStructure([
                'user' => ['id', 'name', 'email', 'role', 'business_id'],
                'business' => ['id', 'name', 'address', 'phone'],
                'token',
            ]);

        $this->assertDatabaseHas('businesses', ['name' => 'Kopi Maju Bersama']);
        $this->assertDatabaseHas('users', [
            'email' => 'bambang@example.com',
            'role' => 'owner',
            'is_active' => true,
        ]);
    }

    public function test_user_can_login_with_valid_credentials(): void
    {
        $business = Business::create(['name' => 'Toko Majunih']);
        $user = User::create([
            'business_id' => $business->id,
            'name' => 'Kasir Satu',
            'email' => 'kasir1@example.com',
            'password' => Hash::make('password123'),
            'role' => 'cashier',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'kasir1@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['user', 'token'])
            ->assertJsonPath('user.email', 'kasir1@example.com');
    }

    public function test_deactivated_user_cannot_login(): void
    {
        $business = Business::create(['name' => 'Toko Majunih']);
        User::create([
            'business_id' => $business->id,
            'name' => 'Kasir Nonaktif',
            'email' => 'kasir_off@example.com',
            'password' => Hash::make('password123'),
            'role' => 'cashier',
            'is_active' => false,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'kasir_off@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(422);
    }

    public function test_authenticated_user_can_view_profile_and_change_password(): void
    {
        $business = Business::create(['name' => 'Toko Majunih']);
        $user = User::create([
            'business_id' => $business->id,
            'name' => 'Owner Ahmad',
            'email' => 'owner_ahmad@example.com',
            'password' => Hash::make('oldpassword'),
            'role' => 'owner',
            'is_active' => true,
        ]);

        $token = $user->createToken('test')->plainTextToken;

        // View Profile
        $this->withToken($token)
            ->getJson('/api/v1/auth/profile')
            ->assertOk()
            ->assertJsonPath('user.name', 'Owner Ahmad')
            ->assertJsonPath('user.business.name', 'Toko Majunih');

        // Change password
        $this->withToken($token)
            ->postJson('/api/v1/auth/password', [
                'current_password' => 'oldpassword',
                'new_password' => 'newpassword123',
                'new_password_confirmation' => 'newpassword123',
            ])
            ->assertOk();

        // Check password changed
        $this->assertTrue(Hash::check('newpassword123', $user->fresh()->password));

        // Logout
        $this->withToken($token)
            ->postJson('/api/v1/auth/logout')
            ->assertOk();
    }
}
