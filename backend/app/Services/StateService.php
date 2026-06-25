<?php

namespace App\Services;

use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Support\MatchMode;
use Illuminate\Support\Collection;

class StateService
{
    public function __construct(
        private QueueService $queueService,
        private MatchService $matchService,
        private MatchModeService $matchModeService,
        private PaymentService $paymentService,
        private ChallengeCourtService $challengeCourtService,
    ) {}

    public function build(PlaySession $session): array
    {
        $history = $this->loadMatchHistory($session, 20);

        return array_merge($this->buildLiveCore($session), [
            'matchHistory' => $history,
            'finishedMatchCount' => $this->finishedMatchCount($session),
            'pendingPayments' => $this->paymentService->pendingForSession($session),
        ]);
    }

    /**
     * Lightweight state for polling — skips heavy history and payment queries.
     */
    public function buildLive(PlaySession $session): array
    {
        $latest = $this->loadMatchHistory($session, 1);

        return array_merge($this->buildLiveCore($session), [
            'matchHistory' => $latest,
            'finishedMatchCount' => $this->finishedMatchCount($session),
            'pendingPayments' => [],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function buildLiveCore(PlaySession $session): array
    {
        $matchRelations = [
            'teamAPlayer1',
            'teamAPlayer2',
            'teamBPlayer1',
            'teamBPlayer2',
        ];

        $courts = Court::query()
            ->where('play_session_id', $session->id)
            ->orderBy('court_number')
            ->get();

        $matchesById = $this->loadCurrentMatches($courts, $matchRelations);

        $queues = $this->queueService->getQueues($session);
        $groupSize = $session->groupSize();
        $queueTypes = $this->matchModeService->queueTypesFor($session);
        $challengeCourtSnapshot = ChallengeCourtSnapshot::load($session);
        $challengeCourt = $this->challengeCourtService->buildState($session, $challengeCourtSnapshot);

        $courtPayloads = $courts->map(function (Court $court) use ($session, $matchesById, $challengeCourtSnapshot) {
            $match = null;
            if ($court->current_match_id) {
                $matchModel = $matchesById->get($court->current_match_id);
                if ($matchModel) {
                    $match = $this->matchService->formatMatch($matchModel);
                }
            }

            return array_merge([
                'id' => $court->id,
                'courtNumber' => $court->court_number,
                'status' => $court->status,
                'skillBracket' => $court->skill_bracket,
                'isChallengeCourt' => (bool) $court->is_challenge_court,
                'currentMatchId' => $court->current_match_id,
                'match' => $match,
            ], $this->challengeCourtService->courtState($session, $court, $challengeCourtSnapshot));
        });

        return [
            'session' => [
                'id' => $session->id,
                'name' => $session->name,
                'status' => $session->status,
                'matchMode' => $session->match_mode,
                'matchModeLabel' => MatchMode::label($session->match_mode),
                'playFormat' => $session->play_format,
                'courtCount' => $session->court_count,
                'nextCourtQueue' => $session->next_court_queue,
                'nextNewPlayerQueue' => $session->next_new_player_queue,
                'queueTypes' => $queueTypes,
                'checkInToken' => $session->check_in_token,
                'autoAssignEnabled' => (bool) $session->auto_assign_enabled,
                'requirePayment' => (bool) $session->require_payment,
                'sessionFeeCents' => (int) $session->session_fee_cents,
                'startedAt' => $session->started_at?->toIso8601String(),
                'endedAt' => $session->ended_at?->toIso8601String(),
            ],
            'queues' => $queues,
            'courts' => $courtPayloads,
            'upNext' => $this->buildUpNext($session, $queues, $groupSize),
            'challengeCourt' => $challengeCourt,
        ];
    }

    private function finishedMatchCount(PlaySession $session): int
    {
        return MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'finished')
            ->count();
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function loadMatchHistory(PlaySession $session, int $limit): Collection
    {
        $matchRelations = [
            'teamAPlayer1',
            'teamAPlayer2',
            'teamBPlayer1',
            'teamBPlayer2',
        ];

        return MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'finished')
            ->with([...$matchRelations, 'court'])
            ->orderByDesc('finished_at')
            ->limit($limit)
            ->get()
            ->map(fn (MatchGame $m) => array_merge(
                $this->matchService->formatMatch($m),
                ['courtNumber' => $m->court?->court_number]
            ));
    }

    /**
     * @param  list<string>  $matchRelations
     * @return Collection<int, MatchGame>
     */
    private function loadCurrentMatches(Collection $courts, array $matchRelations): Collection
    {
        $matchIds = $courts
            ->pluck('current_match_id')
            ->filter()
            ->unique()
            ->values();

        if ($matchIds->isEmpty()) {
            return collect();
        }

        return MatchGame::query()
            ->whereIn('id', $matchIds)
            ->with($matchRelations)
            ->get()
            ->keyBy('id');
    }

    private function buildUpNext(PlaySession $session, array $queues, int $groupSize): array
    {
        $preview = [];

        if (MatchMode::usesSkillQueues($session->match_mode)) {
            foreach ($this->matchModeService->queueTypesFor($session) as $type) {
                $players = array_slice($queues[$type] ?? [], 0, $groupSize);
                if (count($players) > 0) {
                    $preview[] = [
                        'queueType' => $type,
                        'players' => $players,
                        'ready' => count($players) >= $groupSize,
                    ];
                }
            }

            return $preview;
        }

        $nextQueue = $session->next_court_queue;
        $queueOrder = $nextQueue === 'winner'
            ? ['winner', 'loser']
            : ['loser', 'winner'];

        foreach ($queueOrder as $type) {
            $players = array_slice($queues[$type] ?? [], 0, $groupSize);
            if (count($players) > 0) {
                $preview[] = [
                    'queueType' => $type,
                    'players' => $players,
                    'ready' => count($players) >= $groupSize,
                ];
            }
        }

        return $preview;
    }
}
