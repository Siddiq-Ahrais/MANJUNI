<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    


    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->dateTime('transaction_date');
            $table->unsignedBigInteger('total_amount');
            $table->enum('payment_method', ['cash', 'qris', 'transfer', 'other']);
            $table->string('payment_reference')->nullable();
            $table->text('note')->nullable();
            $table->enum('status', ['pending', 'completed', 'cancelled', 'void'])->default('pending');
            $table->dateTime('paid_at')->nullable();
            $table->text('void_reason')->nullable();
            $table->foreignId('voided_by')->nullable()->constrained('users')->nullOnDelete();
            $table->dateTime('voided_at')->nullable();
            $table->timestamps();
        });
    }

    


    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
