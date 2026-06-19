<?php

namespace App\Services;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\SessionPlayer;
use App\Models\TournamentTeamMember;
use App\Support\MatchMode;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ClubPlayerService
{
    public function list(?string $search = null, bool $includeGuests = false): Collection
    {
        $query = ClubPlayer::query()
            ->where('is_tournament_only', false)
            ->orderBy('name');

        if (! $includeGuests) {
            $query->where('is_guest', false);
        }

        if ($search !== null && trim($search) !== '') {
            $term = '%'.trim($search).'%';
            $query->where(function ($q) use ($term) {
                $q->where('name', 'like', $term)
                    ->orWhere('display_name', 'like', $term);
            });
        }

        return $query->get();
    }

    public function register(
        string $name,
        string $skillLevel = 'beginner',
        string $gender = 'male',
    ): ClubPlayer {
        $trimmed = trim($name);

        if ($trimmed === '') {
            throw new \InvalidArgumentException('Player name is required');
        }

        if (! in_array($skillLevel, MatchMode::SKILL_LEVELS, true)) {
            throw new \InvalidArgumentException('Invalid skill level');
        }

        if (! in_array($gender, MatchMode::GENDERS, true)) {
            throw new \InvalidArgumentException('Invalid gender');
        }

        return ClubPlayer::query()->create([
            'name' => 'player:'.Str::lower(Str::random(12)),
            'display_name' => $trimmed,
            'skill_level' => $skillLevel,
            'gender' => $gender,
            'is_guest' => false,
            'is_tournament_only' => false,
        ]);
    }

    public function registerTournamentPlayer(
        string $name,
        string $skillLevel = 'beginner',
        string $gender = 'male',
    ): ClubPlayer {
        $trimmed = trim($name);

        if ($trimmed === '') {
            throw new \InvalidArgumentException('Player name is required');
        }

        if (! in_array($skillLevel, MatchMode::SKILL_LEVELS, true)) {
            throw new \InvalidArgumentException('Invalid skill level');
        }

        if (! in_array($gender, MatchMode::GENDERS, true)) {
            throw new \InvalidArgumentException('Invalid gender');
        }

        return ClubPlayer::query()->create([
            'name' => 'tournament:'.Str::lower(Str::random(12)),
            'display_name' => $trimmed,
            'skill_level' => $skillLevel,
            'gender' => $gender,
            'is_guest' => false,
            'is_tournament_only' => true,
        ]);
    }

    /**
     * @param  list<int>  $clubPlayerIds
     */
    public function purgeOrphanedTournamentOnlyPlayers(array $clubPlayerIds): void
    {
        foreach (array_unique($clubPlayerIds) as $clubPlayerId) {
            $player = ClubPlayer::query()->find($clubPlayerId);

            if ($player === null || ! $player->is_tournament_only) {
                continue;
            }

            $stillRegistered = TournamentTeamMember::query()
                ->where('club_player_id', $clubPlayerId)
                ->exists();

            if (! $stillRegistered) {
                $player->delete();
            }
        }
    }

    public function registerGuest(
        string $name,
        string $skillLevel = 'beginner',
        string $gender = 'male',
    ): ClubPlayer {
        $displayName = trim($name);

        if ($displayName === '') {
            throw new \InvalidArgumentException('Player name is required');
        }

        if (! in_array($skillLevel, MatchMode::SKILL_LEVELS, true)) {
            throw new \InvalidArgumentException('Invalid skill level');
        }

        if (! in_array($gender, MatchMode::GENDERS, true)) {
            throw new \InvalidArgumentException('Invalid gender');
        }

        return ClubPlayer::query()->create([
            'name' => 'guest:'.Str::lower(Str::random(12)),
            'display_name' => $displayName,
            'skill_level' => $skillLevel,
            'gender' => $gender,
            'is_guest' => true,
        ]);
    }

    public function findByName(string $name): ?ClubPlayer
    {
        $trimmed = trim($name);

        return ClubPlayer::query()
            ->where(function ($query) use ($trimmed) {
                $query->where('display_name', $trimmed)
                    ->orWhere('name', $trimmed);
            })
            ->first();
    }

    public function delete(ClubPlayer $clubPlayer): void
    {
        $inActiveSession = Player::query()
            ->active()
            ->where('club_player_id', $clubPlayer->id)
            ->whereHas('playSession', fn ($q) => $q->where('status', 'active'))
            ->exists();

        if ($inActiveSession) {
            throw new \RuntimeException(
                'Cannot delete a player who is in an active session. Remove them from the session first.',
            );
        }

        DB::transaction(function () use ($clubPlayer) {
            TournamentTeamMember::query()
                ->where('club_player_id', $clubPlayer->id)
                ->delete();

            SessionPlayer::query()
                ->where('club_player_id', $clubPlayer->id)
                ->delete();

            Player::query()
                ->where('club_player_id', $clubPlayer->id)
                ->update(['club_player_id' => null]);

            $clubPlayer->delete();
        });
    }

    public function ensureSessionPlayer(PlaySession $session, ClubPlayer $clubPlayer): SessionPlayer
    {
        return SessionPlayer::query()->firstOrCreate(
            [
                'play_session_id' => $session->id,
                'club_player_id' => $clubPlayer->id,
            ],
            [
                'session_matches' => 0,
                'session_wins' => 0,
                'session_losses' => 0,
            ],
        );
    }

    public function formatClubPlayer(ClubPlayer $clubPlayer, ?SessionPlayer $sessionPlayer = null): array
    {
        return [
            'id' => $clubPlayer->id,
            'name' => $clubPlayer->publicName(),
            'isGuest' => (bool) $clubPlayer->is_guest,
            'skillLevel' => $clubPlayer->skill_level,
            'gender' => $clubPlayer->gender,
            'totalMatches' => $clubPlayer->total_matches,
            'totalWins' => $clubPlayer->total_wins,
            'totalLosses' => $clubPlayer->total_losses,
            'pointsScored' => $clubPlayer->total_points_scored,
            'pointsAllowed' => $clubPlayer->total_points_allowed,
            'pointDifferential' => $clubPlayer->pointDifferential(),
            'avgMargin' => $clubPlayer->avgMargin(),
            'winRate' => $clubPlayer->winRate(),
            'sessionMatches' => $sessionPlayer?->session_matches ?? 0,
            'sessionWins' => $sessionPlayer?->session_wins ?? 0,
            'sessionLosses' => $sessionPlayer?->session_losses ?? 0,
            'sessionWinRate' => $sessionPlayer?->sessionWinRate() ?? 0.0,
            'inCurrentSession' => $sessionPlayer !== null,
        ];
    }

    public function recordWin(ClubPlayer $clubPlayer, SessionPlayer $sessionPlayer): void
    {
        DB::transaction(function () use ($clubPlayer, $sessionPlayer) {
            $clubPlayer->increment('total_matches');
            $clubPlayer->increment('total_wins');
            $sessionPlayer->increment('session_matches');
            $sessionPlayer->increment('session_wins');
        });
    }

    public function recordLoss(ClubPlayer $clubPlayer, SessionPlayer $sessionPlayer): void
    {
        DB::transaction(function () use ($clubPlayer, $sessionPlayer) {
            $clubPlayer->increment('total_matches');
            $clubPlayer->increment('total_losses');
            $sessionPlayer->increment('session_matches');
            $sessionPlayer->increment('session_losses');
        });
    }

    public function recordPoints(
        ClubPlayer $clubPlayer,
        SessionPlayer $sessionPlayer,
        int $pointsScored,
        int $pointsAllowed,
    ): void {
        DB::transaction(function () use ($clubPlayer, $sessionPlayer, $pointsScored, $pointsAllowed) {
            $clubPlayer->increment('total_points_scored', $pointsScored);
            $clubPlayer->increment('total_points_allowed', $pointsAllowed);
            $sessionPlayer->increment('session_points_scored', $pointsScored);
            $sessionPlayer->increment('session_points_allowed', $pointsAllowed);
        });
    }
}
