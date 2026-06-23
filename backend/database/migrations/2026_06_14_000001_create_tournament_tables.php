<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('tournaments') && ! Schema::hasColumn('tournaments', 'advance_count')) {
            return;
        }

        if (Schema::hasTable('tournaments')) {
            return;
        }

        Schema::create('tournaments', function (Blueprint $table) {
            $table->id();
            $table->string('name', 120);
            $table->string('status', 32)->default('draft');
            $table->unsignedTinyInteger('advance_count')->default(2);
            $table->unsignedTinyInteger('court_count')->default(4);
            $table->json('settings')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();
        });

        Schema::create('tournament_categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained()->cascadeOnDelete();
            $table->string('category_key', 96);
            $table->boolean('is_enabled')->default(false);
            $table->string('phase', 32)->default('setup');
            $table->timestamps();

            $table->unique(['tournament_id', 'category_key']);
        });

        Schema::create('tournament_teams', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tournament_category_id')->constrained()->cascadeOnDelete();
            $table->string('display_name', 120);
            $table->unsignedTinyInteger('seed')->nullable();
            $table->string('status', 24)->default('active');
            $table->unsignedSmallInteger('wins')->default(0);
            $table->unsignedSmallInteger('losses')->default(0);
            $table->unsignedSmallInteger('points_scored')->default(0);
            $table->unsignedSmallInteger('points_allowed')->default(0);
            $table->timestamps();
        });

        Schema::create('tournament_team_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_team_id')->constrained()->cascadeOnDelete();
            $table->foreignId('club_player_id')->constrained()->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['tournament_team_id', 'club_player_id']);
        });

        Schema::create('tournament_matches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tournament_category_id')->constrained()->cascadeOnDelete();
            $table->string('phase', 32);
            $table->unsignedSmallInteger('round_index')->default(0);
            $table->unsignedSmallInteger('match_index')->default(0);
            $table->foreignId('team_a_id')->nullable()->constrained('tournament_teams')->nullOnDelete();
            $table->foreignId('team_b_id')->nullable()->constrained('tournament_teams')->nullOnDelete();
            $table->unsignedSmallInteger('score_a')->nullable();
            $table->unsignedSmallInteger('score_b')->nullable();
            $table->foreignId('winner_team_id')->nullable()->constrained('tournament_teams')->nullOnDelete();
            $table->string('status', 24)->default('scheduled');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tournament_matches');
        Schema::dropIfExists('tournament_team_members');
        Schema::dropIfExists('tournament_teams');
        Schema::dropIfExists('tournament_categories');
        Schema::dropIfExists('tournaments');
    }
};
