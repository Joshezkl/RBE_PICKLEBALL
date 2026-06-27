<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Queue reads filter players by availability within a session; this
        // composite index lets the availability whereHas resolve via an index
        // instead of scanning all of a session's players.
        if (Schema::hasTable('players') && Schema::hasColumn('players', 'availability')) {
            Schema::table('players', function (Blueprint $table) {
                $table->index(['play_session_id', 'availability'], 'players_session_availability_index');
            });
        }

        // Monthly/season leaderboards range-scan sessions by their start/end
        // timestamps. Index both so the period lookup avoids a full table scan.
        if (Schema::hasTable('play_sessions')) {
            Schema::table('play_sessions', function (Blueprint $table) {
                $table->index('started_at', 'play_sessions_started_at_index');
                $table->index('ended_at', 'play_sessions_ended_at_index');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('players')) {
            Schema::table('players', function (Blueprint $table) {
                $table->dropIndex('players_session_availability_index');
            });
        }

        if (Schema::hasTable('play_sessions')) {
            Schema::table('play_sessions', function (Blueprint $table) {
                $table->dropIndex('play_sessions_started_at_index');
                $table->dropIndex('play_sessions_ended_at_index');
            });
        }
    }
};
