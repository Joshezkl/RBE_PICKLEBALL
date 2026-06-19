<?php

namespace App\Services;

use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use App\Models\SessionPlayer;
use App\Support\MatchMode;
use App\Support\PaymentStatus;
use Illuminate\Http\Request;

class CheckInService
{
    public function __construct(
        private ClubPlayerService $clubPlayerService,
        private PaymentService $paymentService,
    ) {}

    public function resolveSession(Request $request): PlaySession
    {
        $token = $this->tokenFromRequest($request);

        if ($token === null || $token === '') {
            throw new \InvalidArgumentException('Check-in token is required');
        }

        $session = PlaySession::query()
            ->where('check_in_token', $token)
            ->where('status', 'active')
            ->first();

        if (! $session) {
            throw new \RuntimeException('Invalid or expired check-in link');
        }

        return $session;
    }

    public function tokenFromRequest(Request $request): ?string
    {
        return $request->header('X-Check-In-Token')
            ?? $request->query('token')
            ?? $request->input('token');
    }

    public function sessionInfo(PlaySession $session): array
    {
        $mode = $session->match_mode;

        return [
            'sessionId' => $session->id,
            'sessionName' => $session->name,
            'matchMode' => $mode,
            'matchModeLabel' => MatchMode::label($mode),
            'playFormat' => $session->play_format,
            'requiresSkillLevel' => MatchMode::requiresSkillLevel($mode),
            'requiresGender' => MatchMode::requiresGender($mode),
            'requirePayment' => (bool) $session->require_payment,
            'sessionFeeCents' => (int) $session->session_fee_cents,
        ];
    }

    public function sessionRoster(PlaySession $session, ?string $search = null): array
    {
        $query = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->with('clubPlayer')
            ->orderBy('name');

        if ($search !== null && trim($search) !== '') {
            $term = '%'.trim($search).'%';
            $query->where(function ($q) use ($term) {
                $q->where('name', 'like', $term)
                    ->orWhereHas('clubPlayer', function ($club) use ($term) {
                        $club->where('display_name', 'like', $term)
                            ->orWhere('name', 'like', $term);
                    });
            });
        }

        return $query->get()
            ->map(fn (Player $player) => [
                'playerId' => $player->id,
                'clubPlayerId' => $player->club_player_id,
                'name' => $player->clubPlayer?->publicName() ?? $player->name,
                'isGuest' => (bool) $player->clubPlayer?->is_guest,
                'availability' => $player->availability,
            ])
            ->values()
            ->all();
    }

    public function listPlayers(PlaySession $session, ?string $search = null): array
    {
        $sessionPlayersByClubId = \App\Models\SessionPlayer::query()
            ->where('play_session_id', $session->id)
            ->get()
            ->keyBy('club_player_id');

        $activeRosterClubIds = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->whereNotNull('club_player_id')
            ->pluck('club_player_id');

        return $this->clubPlayerService->list($search, includeGuests: false)
            ->map(function ($clubPlayer) use ($sessionPlayersByClubId, $activeRosterClubIds) {
                $formatted = $this->clubPlayerService->formatClubPlayer(
                    $clubPlayer,
                    $sessionPlayersByClubId->get($clubPlayer->id),
                );
                $formatted['inCurrentSession'] = $activeRosterClubIds->contains($clubPlayer->id);

                return $formatted;
            })
            ->values()
            ->all();
    }

    public function resolvePlayer(PlaySession $session, ?int $clubPlayerId, ?int $playerId): ?Player
    {
        if ($playerId !== null) {
            return Player::query()
                ->active()
                ->where('play_session_id', $session->id)
                ->where('id', $playerId)
                ->first();
        }

        if ($clubPlayerId === null) {
            return null;
        }

        return Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayerId)
            ->first();
    }

    public function playerStatus(PlaySession $session, ?int $clubPlayerId = null, ?int $playerId = null): array
    {
        $player = $this->resolvePlayer($session, $clubPlayerId, $playerId);

        if ($player) {
            return $this->formatPlayerStatus($session, $player);
        }

        if ($clubPlayerId !== null) {
            $sessionPlayer = SessionPlayer::query()
                ->where('play_session_id', $session->id)
                ->where('club_player_id', $clubPlayerId)
                ->with('clubPlayer')
                ->first();

            if ($sessionPlayer) {
                if ($sessionPlayer->payment_status === PaymentStatus::PENDING) {
                    return $this->paymentService->formatRegistrationStatus(
                        $session,
                        $sessionPlayer,
                    );
                }

                return [
                    'inSession' => false,
                    'registered' => true,
                    'status' => 'registered',
                    'message' => 'Registered — tap Join to enter the queue',
                    'clubPlayerId' => $clubPlayerId,
                    'playerName' => $sessionPlayer->clubPlayer?->publicName(),
                    'isGuest' => (bool) $sessionPlayer->clubPlayer?->is_guest,
                    'paymentStatus' => $sessionPlayer->payment_status,
                ];
            }
        }

        return [
            'inSession' => false,
            'status' => 'not_joined',
            'message' => 'Not checked in to this session',
        ];
    }

    public function formatPlayerStatus(PlaySession $session, Player $player): array
    {
        $displayName = $player->clubPlayer?->publicName() ?? $player->name;
        $isGuest = (bool) $player->clubPlayer?->is_guest;

        if ($player->availability === 'away') {
            return [
                'inSession' => true,
                'status' => 'away',
                'message' => 'Stepped out — tap I\'m Back when you return',
                'playerId' => $player->id,
                'clubPlayerId' => $player->club_player_id,
                'playerName' => $displayName,
                'isGuest' => $isGuest,
                'sessionWins' => $player->wins,
                'sessionLosses' => $player->losses,
            ];
        }

        $match = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->where(function ($q) use ($player) {
                $q->where('team_a_player1', $player->id)
                    ->orWhere('team_a_player2', $player->id)
                    ->orWhere('team_b_player1', $player->id)
                    ->orWhere('team_b_player2', $player->id);
            })
            ->with('court')
            ->first();

        if ($match && $match->court) {
            $elapsedSeconds = $match->started_at
                ? (int) $match->started_at->diffInSeconds(now())
                : null;

            return [
                'inSession' => true,
                'status' => 'playing',
                'message' => 'On Court '.$match->court->court_number,
                'courtNumber' => $match->court->court_number,
                'elapsedSeconds' => $elapsedSeconds,
                'playerId' => $player->id,
                'clubPlayerId' => $player->club_player_id,
                'playerName' => $displayName,
                'isGuest' => $isGuest,
                'sessionWins' => $player->wins,
                'sessionLosses' => $player->losses,
            ];
        }

        $entry = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('player_id', $player->id)
            ->first();

        if ($entry) {
            $queueLabel = MatchMode::queueLabel($entry->queue_type);
            $playersAhead = max(0, $entry->position - 1);
            $groupSize = $session->groupSize();
            $groupsAhead = (int) floor($playersAhead / $groupSize);

            return [
                'inSession' => true,
                'status' => 'waiting',
                'message' => $groupsAhead > 0
                    ? "Position {$entry->position} in {$queueLabel} · ~{$groupsAhead} group(s) ahead"
                    : "Position {$entry->position} in {$queueLabel} · up soon",
                'queueType' => $entry->queue_type,
                'queueLabel' => $queueLabel,
                'position' => $entry->position,
                'playersAhead' => $playersAhead,
                'groupsAhead' => $groupsAhead,
                'playerId' => $player->id,
                'clubPlayerId' => $player->club_player_id,
                'playerName' => $displayName,
                'isGuest' => $isGuest,
                'sessionWins' => $player->wins,
                'sessionLosses' => $player->losses,
            ];
        }

        return [
            'inSession' => true,
            'status' => 'roster',
            'message' => 'Checked in — waiting to be queued',
            'playerId' => $player->id,
            'clubPlayerId' => $player->club_player_id,
            'playerName' => $displayName,
            'isGuest' => $isGuest,
            'sessionWins' => $player->wins,
            'sessionLosses' => $player->losses,
        ];
    }
}
