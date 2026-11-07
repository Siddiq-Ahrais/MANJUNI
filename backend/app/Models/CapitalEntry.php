<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CapitalEntry extends Model
{
    protected $fillable = [
        'business_id', 'user_id', 'entry_date', 'type', 'amount',
        'source_name', 'note',
    ];

    protected function casts(): array
    {
        return ['entry_date' => 'date', 'amount' => 'integer'];
    }

    public function business(): BelongsTo { return $this->belongsTo(Business::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
}
