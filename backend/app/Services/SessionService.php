<?php

namespace App\Services;

use App\Exceptions\PaymentRequiredException;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\ClubPlayer;
use App\Models\Player;
use App\Support\MatchMode;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SessionService
{
    public function __construct(
        private QueueService $queueService,
        private MatchModeService $matchModeService,
        private ClubPlayerService $clubPlayerService,
        private CourtService $courtService,
        private PaymentService $paymentService,
        private ChallengeCourtService $challengeCourtService,
    ) {}

    public function start(array $data): PlaySession
    {
        return DB::transaction(function () use ($data) {
            $active = PlaySession::query()->where('status', 'active')->exists();
            if ($active) {
                throw new \RuntimeException('An active session already exists. End it before starting a new one.');
            }

            $matchMode = $data['match_mode'] ?? 'auto_balanced';
            $playFormat = $this->matchModeService->resolvePlayFormat(
                $matchMode,
                $data['play_format'] ?? null,
            );

            $session = PlaySession::query()->create([
                'name' => $data['name'] ?? 'Open Play Session',
                'status' => 'active',
                'check_in_token' => Str::random(32),
                'match_mode' => $matchMode,
                'match_mode_settings' => $data['match_mode_settings'] ?? null,
                'play_format' => $playFormat,
                'court_count' => $data['court_count'] ?? 4,
                'auto_assign_enabled' => (bool) ($data['auto_assign_enabled'] ?? false),
                'require_payment' => (bool) ($data['require_payment'] ?? false),
                'session_fee_cents' => (int) ($data['session_fee_cents'] ?? 3000),
                'next_court_queue' => 'winner',
                'next_new_player_queue' => 'winner',
                'started_at' => now(),
            ]);

            for ($i = 1; $i <= $session->court_count; $i++) {
                Court::query()->create([
                    'play_session_id' => $session->id,
                    'court_number' => $i,
                    'status' => 'available',
                ]);
            }

            $this->matchModeService->configureSession($session->fresh());
            $this->challengeCourtService->initializeForSession($session->fresh());

            return $session->fresh();
        });
    }

    public function addPlayer(PlaySession $session, string $name, ?string $skillLevel = null, ?string $gender = null, ?string $paymentAction = null): Player
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        $trimmed = trim($name);
        $exists = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('name', $trimmed)
            ->exists();

        if ($exists) {
            throw new \RuntimeException('Player name already exists in this session');
        }

        $clubPlayer = $this->clubPlayerService->findByName($trimmed);
        if (! $clubPlayer) {
            $resolvedSkill = $this->resolveSkillLevel($session, null, $skillLevel);
            $resolvedGender = $this->resolveGender($session, null, $gender);
            $clubPlayer = $this->clubPlayerService->register(
                $trimmed,
                $resolvedSkill ?? 'beginner',
                $resolvedGender ?? 'male',
            );
        }

        return $this->addClubPlayerToSession($session, $clubPlayer, $skillLevel, $gender, $paymentAction);
    }

    public function addClubPlayerToSession(
        PlaySession $session,
        ClubPlayer $clubPlayer,
        ?string $skillLevel = null,
        ?string $gender = null,
        ?string $paymentAction = null,
    ): Player {
        $this->paymentService->applyPaymentAction($session, $clubPlayer, $paymentAction);

        return $this->activateClubPlayerInSession($session, $clubPlayer, $skillLevel, $gender);
    }

    public function activateClubPlayerInSession(
        PlaySession $session,
        ClubPlayer $clubPlayer,
        ?string $skillLevel = null,
        ?string $gender = null,
    ): Player {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        $resolvedSkill = $this->resolveSkillLevel($session, $clubPlayer, $skillLevel);
        $resolvedGender = $this->resolveGender($session, $clubPlayer, $gender);

        $sessionPlayer = $this->paymentService->ensureRegistration($session, $clubPlayer);
        if (! $sessionPlayer->canJoinQueue()) {
            throw new PaymentRequiredException('Payment required before joining the queue');
        }

        $existing = Player::query()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->first();

        if ($existing) {
            if ($existing->is_active) {
                throw new \RuntimeException('Player is already in this session');
            }

            return $this->reactivatePlayer(
                $session,
                $existing,
                $resolvedSkill,
                $resolvedGender,
            );
        }

        $this->clubPlayerService->ensureSessionPlayer($session, $clubPlayer);

        $player = Player::query()->create([
            'play_session_id' => $session->id,
            'club_player_id' => $clubPlayer->id,
            'name' => $clubPlayer->publicName(),
            'skill_level' => $resolvedSkill,
            'gender' => $resolvedGender,
            'is_active' => true,
        ]);

        $this->queueService->addNewPlayer($session->fresh(), $player);

        $this->courtService->tryAutoAssignAvailableCourts($session->fresh());

        return $player->fresh();
    }

    public function tryActivateAfterPayment(PlaySession $session, ClubPlayer $clubPlayer): ?Player
    {
        if (! $session->isActive()) {
            return null;
        }

        $hasActivePlayer = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->exists();

        if ($hasActivePlayer) {
            return Player::query()
                ->active()
                ->where('play_session_id', $session->id)
                ->where('club_player_id', $clubPlayer->id)
                ->first();
        }

        try {
            return $this->activateClubPlayerInSession($session, $clubPlayer);
        } catch (PaymentRequiredException|\InvalidArgumentException|\RuntimeException) {
            return null;
        }
    }

    public function updateSettings(PlaySession $session, array $data): PlaySession
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        if (array_key_exists('auto_assign_enabled', $data)) {
            $session->update([
                'auto_assign_enabled' => (bool) $data['auto_assign_enabled'],
            ]);
        }

        if (array_key_exists('require_payment', $data)) {
            $session->update([
                'require_payment' => (bool) $data['require_payment'],
            ]);
        }

        if (array_key_exists('session_fee_cents', $data)) {
            $session->update([
                'session_fee_cents' => max(0, (int) $data['session_fee_cents']),
            ]);
        }

        if (array_key_exists('court_count', $data)) {
            $this->courtService->resizeCourtCount($session, (int) $data['court_count']);
        }

        return $session->fresh();
    }

    public function updatePlayerName(PlaySession $session, Player $player, string $name): Player
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        if ($player->play_session_id !== $session->id) {
            throw new \RuntimeException('Player not in this session');
        }

        $trimmed = trim($name);
        if ($trimmed === '') {
            throw new \InvalidArgumentException('Player name is required');
        }

        $duplicate = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('name', $trimmed)
            ->where('id', '!=', $player->id)
            ->exists();

        if ($duplicate) {
            throw new \RuntimeException('Player name already exists in this session');
        }

        $player->update(['name' => $trimmed]);

        if ($player->club_player_id) {
            $clubPlayer = ClubPlayer::query()->find($player->club_player_id);
            if ($clubPlayer) {
                if ($clubPlayer->display_name) {
                    $clubPlayer->update(['display_name' => $trimmed]);
                } else {
                    $clubPlayer->update(['name' => $trimmed]);
                }
            }
        }

        return $player->fresh();
    }

    public function removePlayer(PlaySession $session, Player $player): void
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        if (! $player->is_active) {
            return;
        }

        $onCourt = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->where(function ($q) use ($player) {
                $q->where('team_a_player1', $player->id)
                    ->orWhere('team_a_player2', $player->id)
                    ->orWhere('team_b_player1', $player->id)
                    ->orWhere('team_b_player2', $player->id);
            })
            ->exists();

        if ($onCourt) {
            throw new \RuntimeException('Cannot remove a player who is currently on a court');
        }

        $this->queueService->removePlayer($session, $player);

        Player::query()
            ->where('play_session_id', $session->id)
            ->where('last_partner_id', $player->id)
            ->update(['last_partner_id' => null]);

        if ($this->playerHasMatchHistory($session, $player)) {
            $player->update(['is_active' => false]);

            return;
        }

        $player->delete();
    }

    public function moveQueuePlayer(
        PlaySession $session,
        Player $player,
        string $queueType,
        int $position,
    ): void {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        if ($player->play_session_id !== $session->id) {
            throw new \InvalidArgumentException('Player not in this session');
        }

        $validTypes = $this->matchModeService->queueTypesFor($session);
        if (! in_array($queueType, $validTypes, true)) {
            throw new \InvalidArgumentException('Invalid queue type');
        }

        $this->queueService->movePlayer($session, $player, $queueType, $position);
    }

    private function reactivatePlayer(
        PlaySession $session,
        Player $player,
        ?string $skillLevel,
        ?string $gender,
    ): Player {
        $this->clubPlayerService->ensureSessionPlayer($session, $player->clubPlayer);

        $player->update([
            'skill_level' => $skillLevel,
            'gender' => $gender,
            'is_active' => true,
        ]);

        $this->queueService->addNewPlayer($session->fresh(), $player->fresh());

        $this->courtService->tryAutoAssignAvailableCourts($session->fresh());

        return $player->fresh();
    }

    private function playerHasMatchHistory(PlaySession $session, Player $player): bool
    {
        return MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where(function ($q) use ($player) {
                $q->where('team_a_player1', $player->id)
                    ->orWhere('team_a_player2', $player->id)
                    ->orWhere('team_b_player1', $player->id)
                    ->orWhere('team_b_player2', $player->id);
            })
            ->exists();
    }

    public function end(PlaySession $session): array
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is already ended');
        }

        $activeMatches = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->count();

        if ($activeMatches > 0) {
            throw new \RuntimeException('Cannot end session while matches are in progress');
        }

        $report = $this->buildReport($session);
        $session->update([
            'status' => 'ended',
            'ended_at' => now(),
            'report_data' => $report,
        ]);

        return $report;
    }

    public function buildReport(PlaySession $session): array
    {
        $session->load(['players', 'courts']);

        $finishedMatches = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'finished')
            ->orderBy('finished_at')
            ->get();

        $queues = $this->queueService->getQueues($session);

        $startedAt = $session->started_at ?? $session->created_at;
        $endedAt = $session->ended_at ?? now();
        $durationMinutes = (int) round($startedAt->diffInMinutes($endedAt));

        $utilization = $this->calculateCourtUtilization($session, $finishedMatches, $startedAt, $endedAt);

        $playerSummaries = $session->players->map(fn (Player $p) => [
            'id' => $p->id,
            'name' => $p->name,
            'wins' => $p->wins,
            'losses' => $p->losses,
            'matchesPlayed' => $p->wins + $p->losses,
        ])->sortByDesc('wins')->values()->all();

        $matchSummaries = $finishedMatches->map(function (MatchGame $match) {
            $durationMinutes = 0;
            if ($match->started_at && $match->finished_at) {
                $durationMinutes = (int) round($match->started_at->diffInMinutes($match->finished_at));
            }

            return [
                'id' => $match->id,
                'courtId' => $match->court_id,
                'durationMinutes' => $durationMinutes,
                'startedAt' => $match->started_at?->toIso8601String(),
                'finishedAt' => $match->finished_at?->toIso8601String(),
            ];
        })->values()->all();

        $avgMatchDurationMinutes = $finishedMatches->isEmpty()
            ? 0
            : (int) round(collect($matchSummaries)->avg('durationMinutes'));

        return [
            'sessionId' => $session->id,
            'sessionName' => $session->name,
            'totalMatches' => $finishedMatches->count(),
            'durationMinutes' => $durationMinutes,
            'avgMatchDurationMinutes' => $avgMatchDurationMinutes,
            'startedAt' => $startedAt->toIso8601String(),
            'endedAt' => $endedAt->toIso8601String(),
            'queueDistribution' => $this->formatQueueDistribution($queues),
            'courtUtilizationPercent' => $utilization,
            'playerSummaries' => $playerSummaries,
            'matchSummaries' => $matchSummaries,
        ];
    }

    /**
     * @param  array<string, list<array<string, mixed>>>  $queues
     * @return array<string, mixed>
     */
    private function formatQueueDistribution(array $queues): array
    {
        $distribution = [
            'winnersQueueSize' => count($queues['winner'] ?? []),
            'losersQueueSize' => count($queues['loser'] ?? []),
            'byQueue' => [],
        ];

        foreach ($queues as $type => $players) {
            $distribution['byQueue'][$type] = count($players);
        }

        foreach (MatchMode::SKILL_LEVELS as $skill) {
            $distribution["{$skill}QueueSize"] = count($queues[$skill] ?? []);
        }

        return $distribution;
    }

    /**
     * @param  \Illuminate\Support\Collection<int, MatchGame>  $matches
     */
    private function calculateCourtUtilization(
        PlaySession $session,
        $matches,
        Carbon $startedAt,
        Carbon $endedAt,
    ): float {
        $totalSeconds = max(1, $startedAt->diffInSeconds($endedAt));
        $courtCount = max(1, $session->court_count);
        $occupiedSeconds = 0;

        foreach ($matches as $match) {
            $start = $match->started_at ?? $startedAt;
            $end = $match->finished_at ?? $endedAt;
            $occupiedSeconds += $start->diffInSeconds($end);
        }

        $activeMatches = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->get();

        foreach ($activeMatches as $match) {
            $start = $match->started_at ?? now();
            $occupiedSeconds += $start->diffInSeconds(now());
        }

        $maxCapacitySeconds = $totalSeconds * $courtCount;

        return round(min(100, ($occupiedSeconds / $maxCapacitySeconds) * 100), 1);
    }

    private function resolveSkillLevel(
        PlaySession $session,
        ?ClubPlayer $clubPlayer,
        ?string $requestedSkill,
    ): ?string {
        if (! $this->matchModeService->requiresSkillLevel($session->match_mode)) {
            return $requestedSkill ?? $clubPlayer?->skill_level;
        }

        $resolved = $requestedSkill ?? $clubPlayer?->skill_level;

        if (! in_array($resolved, MatchMode::SKILL_LEVELS, true)) {
            throw new \InvalidArgumentException(
                'Player must have a registered skill level before joining a skill-based session',
            );
        }

        return $resolved;
    }

    private function resolveGender(
        PlaySession $session,
        ?ClubPlayer $clubPlayer,
        ?string $requestedGender,
    ): ?string {
        if (! $this->matchModeService->requiresGender($session->match_mode)) {
            return $requestedGender ?? $clubPlayer?->gender;
        }

        $resolved = $requestedGender ?? $clubPlayer?->gender;

        if (! in_array($resolved, MatchMode::GENDERS, true)) {
            throw new \InvalidArgumentException(
                'Player must have a registered gender before joining a mixed doubles session',
            );
        }

        return $resolved;
    }
}
