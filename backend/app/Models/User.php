<?php

namespace App\Models;


use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Authenticatable
{
    
    use HasApiTokens, HasFactory, Notifiable;

    




    protected $fillable = [
        'business_id',
        'name',
        'email',
        'password',
        'role',
        'is_active',
    ];

    




    protected $hidden = [
        'password',
        'remember_token',
    ];

    




    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function business(): BelongsTo
    {
        return $this->belongsTo(Business::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function voidedTransactions(): HasMany
    {
        return $this->hasMany(Transaction::class, 'voided_by');
    }

    public function expenses(): HasMany
    {
        return $this->hasMany(Expense::class);
    }

    public function capitalEntries(): HasMany
    {
        return $this->hasMany(CapitalEntry::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    public function plans(): HasMany
    {
        return $this->hasMany(Plan::class);
    }
}
