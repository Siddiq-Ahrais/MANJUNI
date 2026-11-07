<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Expense extends Model
{
    protected $fillable = [
        'business_id', 'user_id', 'expense_date', 'category', 'amount',
        'note', 'status', 'void_reason',
    ];

    protected function casts(): array
    {
        return ['expense_date' => 'date', 'amount' => 'integer'];
    }

    public function business(): BelongsTo { return $this->belongsTo(Business::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
}
