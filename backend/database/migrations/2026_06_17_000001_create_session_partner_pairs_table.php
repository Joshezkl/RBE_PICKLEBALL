<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('session_partner_pairs')) {
            return;
        }

        Schema::create('session_partner_pairs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('player_one_id')->constrained('players')->cascadeOnDelete();
            $table->foreignId('player_two_id')->constrained('players')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['play_session_id', 'player_one_id', 'player_two_id']);
        });

        $this->backfillFromMatches();
    }

    public function down(): void
    {
        Schema::dropIfExists('session_partner_pairs');
    }

    private function backfillFromMatches(): void
    {
        $query = DB::table('matches')
            ->whereNotNull('team_a_player2')
            ->whereNotNull('team_b_player2')
            ->select([
                'play_session_id',
                'team_a_player1',
                'team_a_player2',
                'team_b_player1',
                'team_b_player2',
            ]);

        if (Schema::hasColumn('matches', 'is_challenge_court')) {
            $query->where('is_challenge_court', false);
        }

        $now = now();
        $rows = [];

        foreach ($query->get() as $match) {
            foreach (
                [
                    [(int) $match->team_a_player1, (int) $match->team_a_player2],
                    [(int) $match->team_b_player1, (int) $match->team_b_player2],
                ] as [$a, $b]
            ) {
                [$low, $high] = $a < $b ? [$a, $b] : [$b, $a];
                $key = "{$match->play_session_id}:{$low}:{$high}";
                $rows[$key] = [
                    'play_session_id' => $match->play_session_id,
                    'player_one_id' => $low,
                    'player_two_id' => $high,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        if ($rows !== []) {
            DB::table('session_partner_pairs')->insert(array_values($rows));
        }
    }
};
