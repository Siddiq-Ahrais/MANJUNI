<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Plan extends Model
{
    protected $fillable = [
        'business_id', 'user_id', 'title', 'description', 'due_date',
        'target_amount', 'status',
    ];

    protected function casts(): array
    {
        return ['due_date' => 'date', 'target_amount' => 'integer'];
    }

    public function business(): BelongsTo { return $this->belongsTo(Business::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
}
