<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TransactionItem extends Model
{
    protected $fillable = [
        'transaction_id', 'product_id', 'item_name', 'quantity', 'unit_price',
        'cost_price', 'subtotal',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_price' => 'integer',
            'cost_price' => 'integer',
            'subtotal' => 'integer',
        ];
    }

    public function transaction(): BelongsTo { return $this->belongsTo(Transaction::class); }
    public function product(): BelongsTo { return $this->belongsTo(Product::class); }
}
