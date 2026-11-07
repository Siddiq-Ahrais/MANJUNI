<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    


    public function up(): void
    {
        Schema::create('capital_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->date('entry_date');
            $table->enum('type', ['initial', 'addition', 'withdrawal']);
            $table->unsignedBigInteger('amount');
            $table->string('source_name')->nullable();
            $table->text('note')->nullable();
            $table->timestamps();
        });
    }

    


    public function down(): void
    {
        Schema::dropIfExists('capital_entries');
    }
};
