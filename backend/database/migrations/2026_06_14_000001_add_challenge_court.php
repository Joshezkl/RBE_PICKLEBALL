<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('courts', function (Blueprint $table) {
            $table->boolean('is_challenge_court')->default(false)->after('skill_bracket');
        });

        Schema::table('matches', function (Blueprint $table) {
            $table->boolean('is_challenge_court')->default(false)->after('status');
        });

        Schema::create('challenge_court_teams', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained()->cascadeOnDelete();
            $table->foreignId('player1_id')->constrained('players')->cascadeOnDelete();
            $table->foreignId('player2_id')->nullable()->constrained('players')->nullOnDelete();
            $table->unsignedInteger('position');
            $table->string('status', 16)->default('queued');
            $table->foreignId('current_match_id')->nullable()->constrained('matches')->nullOnDelete();
            $table->timestamps();

            $table->index(['play_session_id', 'status', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('challenge_court_teams');

        Schema::table('matches', function (Blueprint $table) {
            $table->dropColumn('is_challenge_court');
        });

        Schema::table('courts', function (Blueprint $table) {
            $table->dropColumn('is_challenge_court');
        });
    }
};
