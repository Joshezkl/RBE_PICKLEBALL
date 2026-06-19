<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tournament_matches', function (Blueprint $table) {
            $table->foreignId('feeds_into_match_id')
                ->nullable()
                ->after('winner_team_id')
                ->constrained('tournament_matches')
                ->nullOnDelete();
            $table->string('feed_slot', 8)->nullable()->after('feeds_into_match_id');
        });
    }

    public function down(): void
    {
        Schema::table('tournament_matches', function (Blueprint $table) {
            $table->dropConstrainedForeignId('feeds_into_match_id');
            $table->dropColumn('feed_slot');
        });
    }
};
