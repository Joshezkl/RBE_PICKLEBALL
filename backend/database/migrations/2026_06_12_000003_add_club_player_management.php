<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('club_players', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->unsignedInteger('total_matches')->default(0);
            $table->unsignedInteger('total_wins')->default(0);
            $table->unsignedInteger('total_losses')->default(0);
            $table->timestamps();
        });

        Schema::create('session_players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('club_player_id')->constrained('club_players')->cascadeOnDelete();
            $table->unsignedInteger('session_matches')->default(0);
            $table->unsignedInteger('session_wins')->default(0);
            $table->unsignedInteger('session_losses')->default(0);
            $table->timestamps();

            $table->unique(['play_session_id', 'club_player_id']);
        });

        Schema::table('players', function (Blueprint $table) {
            $table->foreignId('club_player_id')
                ->nullable()
                ->after('play_session_id')
                ->constrained('club_players')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('players', function (Blueprint $table) {
            $table->dropConstrainedForeignId('club_player_id');
        });

        Schema::dropIfExists('session_players');
        Schema::dropIfExists('club_players');
    }
};
