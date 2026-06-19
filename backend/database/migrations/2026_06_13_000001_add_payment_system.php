<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->boolean('require_payment')->default(false)->after('auto_assign_enabled');
            $table->unsignedInteger('session_fee_cents')->default(3000)->after('require_payment');
        });

        Schema::table('session_players', function (Blueprint $table) {
            $table->string('payment_status', 16)->default('free')->after('session_losses');
            $table->unsignedInteger('payment_amount_cents')->nullable()->after('payment_status');
            $table->string('payment_method', 16)->nullable()->after('payment_amount_cents');
            $table->timestamp('paid_at')->nullable()->after('payment_method');
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('club_player_id')->constrained('club_players')->cascadeOnDelete();
            $table->foreignId('session_player_id')->nullable()->constrained('session_players')->nullOnDelete();
            $table->unsignedInteger('amount_cents');
            $table->string('method', 16)->default('cash');
            $table->string('status', 16)->default('completed');
            $table->timestamp('recorded_at');
            $table->string('notes')->nullable();
            $table->timestamps();

            $table->index(['play_session_id', 'recorded_at']);
            $table->index(['club_player_id', 'recorded_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');

        Schema::table('session_players', function (Blueprint $table) {
            $table->dropColumn([
                'payment_status',
                'payment_amount_cents',
                'payment_method',
                'paid_at',
            ]);
        });

        Schema::table('play_sessions', function (Blueprint $table) {
            $table->dropColumn(['require_payment', 'session_fee_cents']);
        });
    }
};
