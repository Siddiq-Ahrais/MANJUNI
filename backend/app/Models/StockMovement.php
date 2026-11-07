<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockMovement extends Model
{
    protected $fillable = [
        'product_id', 'user_id', 'transaction_item_id', 'type',
        'quantity_change', 'stock_after', 'note',
    ];

    protected function casts(): array
    {
        return ['quantity_change' => 'integer', 'stock_after' => 'integer'];
    }

    public function product(): BelongsTo { return $this->belongsTo(Product::class); }
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function transactionItem(): BelongsTo { return $this->belongsTo(TransactionItem::class); }
}
