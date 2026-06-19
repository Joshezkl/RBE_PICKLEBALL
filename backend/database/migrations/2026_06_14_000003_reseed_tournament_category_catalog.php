<?php

use App\Models\Tournament;
use App\Models\TournamentCategory;
use App\Support\TournamentCategory as TournamentCategorySupport;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('tournament_categories')) {
            return;
        }

        Schema::disableForeignKeyConstraints();
        DB::table('tournament_matches')->delete();
        DB::table('tournament_team_members')->delete();
        DB::table('tournament_teams')->delete();
        DB::table('tournament_categories')->delete();
        Schema::enableForeignKeyConstraints();

        Tournament::query()->each(function (Tournament $tournament) {
            foreach (TournamentCategorySupport::allCategoryKeys() as $categoryKey) {
                TournamentCategory::query()->create([
                    'tournament_id' => $tournament->id,
                    'category_key' => $categoryKey,
                    'is_enabled' => false,
                    'phase' => 'setup',
                ]);
            }

            if (in_array($tournament->status, ['round_robin', 'single_elimination'], true)) {
                $tournament->update([
                    'status' => 'setup',
                    'started_at' => null,
                    'ended_at' => null,
                ]);
            }
        });
    }

    public function down(): void
    {
        //
    }
};
