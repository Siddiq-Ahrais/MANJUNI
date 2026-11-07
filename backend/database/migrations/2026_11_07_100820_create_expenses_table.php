<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    


    public function up(): void
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->date('expense_date');
            $table->string('category');
            $table->unsignedBigInteger('amount');
            $table->text('note')->nullable();
            $table->enum('status', ['completed', 'void'])->default('completed');
            $table->text('void_reason')->nullable();
            $table->timestamps();
        });
    }

    


    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
