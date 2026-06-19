<?php

namespace App\Services;

use App\Models\Court;
use App\Models\ChallengeCourtTeam;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use Illuminate\Support\Collection;

class MatchService
{
    public function __construct(
        private PairingService $pairingService,
        private QueueService $queueService,
        private MatchModeService $matchModeService,
        private PlayerStatsService $playerStatsService,
    ) {}

    /**
     * @param  array{teamA: array<int, Player>, teamB: array<int, Player>}  $teams
     */
    public function createMatch(PlaySession $session, Court $court, array $teams): MatchGame
    {
        $teamA = $teams['teamA'];
        $teamB = $teams['teamB'];

        $match = MatchGame::query()->create([
            'play_session_id' => $session->id,
            'court_id' => $court->id,
            'team_a_player1' => $teamA[0]->id,
            'team_a_player2' => $teamA[1]->id ?? null,
            'team_b_player1' => $teamB[0]->id,
            'team_b_player2' => $teamB[1]->id ?? null,
            'status' => 'in_match',
            'started_at' => now(),
        ]);

        $court->update([
            'status' => 'in_match',
            'current_match_id' => $match->id,
        ]);

        $this->pairingService->updatePartnerState($session, $teamA, $teamB);

        return $match->load([
            'teamAPlayer1',
            'teamAPlayer2',
            'teamBPlayer1',
            'teamBPlayer2',
        ]);
    }

    public function createChallengeCourtMatch(
        PlaySession $session,
        Court $court,
        ChallengeCourtTeam $teamA,
        ChallengeCourtTeam $teamB,
    ): MatchGame {
        $match = MatchGame::query()->create([
            'play_session_id' => $session->id,
            'court_id' => $court->id,
            'team_a_player1' => $teamA->player1_id,
            'team_a_player2' => $teamA->player2_id,
            'team_b_player1' => $teamB->player1_id,
            'team_b_player2' => $teamB->player2_id,
            'status' => 'in_match',
            'is_challenge_court' => true,
            'started_at' => now(),
        ]);

        $court->update([
            'status' => 'in_match',
            'current_match_id' => $match->id,
        ]);

        return $match->load([
            'teamAPlayer1',
            'teamAPlayer2',
            'teamBPlayer1',
            'teamBPlayer2',
        ]);
    }

    public function finishMatch(
        PlaySession $session,
        MatchGame $match,
        int $scoreA,
        int $scoreB,
    ): MatchGame {
        if ($match->status === 'finished') {
            throw new \RuntimeException('Match already finished');
        }

        if ($scoreA === $scoreB) {
            throw new \InvalidArgumentException('Scores cannot be tied');
        }

        $winnerTeam = $scoreA > $scoreB ? 'A' : 'B';

        $match->update([
            'score_a' => $scoreA,
            'score_b' => $scoreB,
            'winner_team' => $winnerTeam,
            'status' => 'finished',
            'finished_at' => now(),
        ]);

        $teamA = $this->loadTeamPlayers($match, 'A');
        $teamB = $this->loadTeamPlayers($match, 'B');

        $winnerIds = $winnerTeam === 'A'
            ? $teamA->pluck('id')->all()
            : $teamB->pluck('id')->all();
        $loserIds = $winnerTeam === 'A'
            ? $teamB->pluck('id')->all()
            : $teamA->pluck('id')->all();

        Player::query()->whereIn('id', $winnerIds)->increment('wins');
        Player::query()->whereIn('id', $loserIds)->increment('losses');

        $winnerScore = $winnerTeam === 'A' ? $scoreA : $scoreB;
        $loserScore = $winnerTeam === 'A' ? $scoreB : $scoreA;
        $this->playerStatsService->recordMatchOutcome(
            $session,
            $winnerIds,
            $loserIds,
            $winnerScore,
            $loserScore,
        );

        $court = Court::query()->findOrFail($match->court_id);

        if (! $match->is_challenge_court) {
            $this->matchModeService->enqueueAfterMatch(
                $session,
                $this->queueService,
                $winnerIds,
                $loserIds,
                $court->court_number,
            );
        }

        $court->update([
            'status' => 'available',
            'current_match_id' => null,
        ]);

        return $match->fresh([
            'teamAPlayer1',
            'teamAPlayer2',
            'teamBPlayer1',
            'teamBPlayer2',
        ]);
    }

    /**
     * @return Collection<int, Player>
     */
    private function loadTeamPlayers(MatchGame $match, string $team): Collection
    {
        $players = collect();
        if ($team === 'A') {
            $players->push($match->teamAPlayer1);
            if ($match->team_a_player2) {
                $players->push($match->teamAPlayer2);
            }
        } else {
            $players->push($match->teamBPlayer1);
            if ($match->team_b_player2) {
                $players->push($match->teamBPlayer2);
            }
        }

        return $players->filter();
    }

    public function formatMatch(MatchGame $match): array
    {
        $elapsedSeconds = null;
        $durationMinutes = null;

        if ($match->started_at) {
            if ($match->status === 'in_match') {
                $elapsedSeconds = (int) $match->started_at->diffInSeconds(now());
            } elseif ($match->finished_at) {
                $durationMinutes = (int) round($match->started_at->diffInMinutes($match->finished_at));
            }
        }

        return [
            'id' => $match->id,
            'courtId' => $match->court_id,
            'status' => $match->status,
            'scoreA' => $match->score_a,
            'scoreB' => $match->score_b,
            'winnerTeam' => $match->winner_team,
            'startedAt' => $match->started_at?->toIso8601String(),
            'finishedAt' => $match->finished_at?->toIso8601String(),
            'elapsedSeconds' => $elapsedSeconds,
            'durationMinutes' => $durationMinutes,
            'isChallengeCourt' => (bool) $match->is_challenge_court,
            'teamA' => [
                'player1' => $this->formatPlayer($match->teamAPlayer1),
                'player2' => $match->teamAPlayer2 ? $this->formatPlayer($match->teamAPlayer2) : null,
            ],
            'teamB' => [
                'player1' => $this->formatPlayer($match->teamBPlayer1),
                'player2' => $match->teamBPlayer2 ? $this->formatPlayer($match->teamBPlayer2) : null,
            ],
        ];
    }

    private function formatPlayer(?Player $player): ?array
    {
        if (! $player) {
            return null;
        }

        return [
            'id' => $player->id,
            'name' => $player->name,
        ];
    }
}
