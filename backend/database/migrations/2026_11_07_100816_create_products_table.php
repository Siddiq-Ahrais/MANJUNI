<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    


    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->string('barcode')->nullable();
            $table->string('unit');
            $table->unsignedBigInteger('cost_price');
            $table->unsignedBigInteger('selling_price');
            $table->integer('stock')->default(0);
            $table->integer('min_stock')->default(0);
            $table->boolean('is_active')->default(true);
            $table->softDeletes();
            $table->unique(['business_id', 'barcode']);
            $table->timestamps();
        });
    }

    


    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
