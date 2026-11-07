<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Transaction extends Model
{
    protected $fillable = [
        'business_id', 'user_id', 'transaction_date', 'total_amount',
        'payment_method', 'payment_reference', 'note', 'status', 'paid_at',
        'void_reason', 'voided_by', 'voided_at',
    ];

    protected function casts(): array
    {
        return [
            'transaction_date' => 'datetime',
            'paid_at' => 'datetime',
            'voided_at' => 'datetime',
            'total_amount' => 'integer',
        ];
    }

    public function business(): BelongsTo { return $this->belongsTo(Business::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function voidedBy(): BelongsTo { return $this->belongsTo(User::class, 'voided_by'); }
    public function items(): HasMany { return $this->hasMany(TransactionItem::class); }
}
