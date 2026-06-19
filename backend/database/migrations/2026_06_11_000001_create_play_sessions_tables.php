<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('play_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('status', ['active', 'ended'])->default('active');
            $table->enum('play_format', ['doubles', 'singles'])->default('doubles');
            $table->unsignedTinyInteger('court_count')->default(4);
            $table->enum('next_court_queue', ['winner', 'loser'])->default('winner');
            $table->enum('next_new_player_queue', ['winner', 'loser'])->default('winner');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->json('report_data')->nullable();
            $table->timestamps();
        });

        Schema::create('players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->string('name');
            $table->foreignId('last_partner_id')->nullable()->constrained('players')->nullOnDelete();
            $table->enum('partner_phase', ['together', 'split_next'])->default('together');
            $table->unsignedInteger('wins')->default(0);
            $table->unsignedInteger('losses')->default(0);
            $table->timestamps();

            $table->unique(['play_session_id', 'name']);
        });

        Schema::create('courts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->unsignedTinyInteger('court_number');
            $table->enum('status', ['available', 'in_match', 'waiting_result'])->default('available');
            $table->unsignedBigInteger('current_match_id')->nullable();
            $table->timestamps();

            $table->unique(['play_session_id', 'court_number']);
        });

        Schema::create('queues', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('player_id')->constrained('players')->cascadeOnDelete();
            $table->enum('queue_type', ['winner', 'loser']);
            $table->unsignedInteger('position');
            $table->timestamps();

            $table->unique(['play_session_id', 'player_id']);
            $table->index(['play_session_id', 'queue_type', 'position']);
        });

        Schema::create('matches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('court_id')->constrained('courts')->cascadeOnDelete();
            $table->foreignId('team_a_player1')->constrained('players');
            $table->foreignId('team_a_player2')->nullable()->constrained('players');
            $table->foreignId('team_b_player1')->constrained('players');
            $table->foreignId('team_b_player2')->nullable()->constrained('players');
            $table->unsignedSmallInteger('score_a')->nullable();
            $table->unsignedSmallInteger('score_b')->nullable();
            $table->enum('winner_team', ['A', 'B'])->nullable();
            $table->enum('status', ['in_match', 'waiting_result', 'finished'])->default('in_match');
            $table->timestamp('started_at')->useCurrent();
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();

            $table->index(['play_session_id', 'status']);
            $table->index(['play_session_id', 'finished_at']);
        });

        Schema::table('courts', function (Blueprint $table) {
            $table->foreign('current_match_id')->references('id')->on('matches')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('courts', function (Blueprint $table) {
            $table->dropForeign(['current_match_id']);
        });

        Schema::dropIfExists('matches');
        Schema::dropIfExists('queues');
        Schema::dropIfExists('courts');
        Schema::dropIfExists('players');
        Schema::dropIfExists('play_sessions');
    }
};
