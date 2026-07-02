<?php

namespace Tests\Feature;

use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SessionFlowTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_start_session_and_register_players_alternate_queues_in_pairs(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Test Session',
                'court_count' => 2,
                'play_format' => 'doubles',
            ]);

        $response->assertCreated();
        $sessionId = $response->json('session.id');

        foreach (['Alice', 'Bob', 'Carol', 'Dave'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$sessionId}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$sessionId}/state")->json();

        $this->assertCount(2, $state['queues']['winner']);
        $this->assertCount(2, $state['queues']['loser']);
        $this->assertEquals(['Alice', 'Bob'], collect($state['queues']['winner'])->pluck('name')->all());
        $this->assertEquals(['Carol', 'Dave'], collect($state['queues']['loser'])->pluck('name')->all());
        $this->assertEquals('winner', $state['session']['nextNewPlayerQueue']);
    }

    public function test_registering_players_does_not_auto_assign_courts_when_disabled(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $activeCourts = collect($state['courts'])->where('status', 'in_match');

        $this->assertCount(0, $activeCourts);
        $this->assertCount(2, $state['courts']);
        foreach ($state['courts'] as $court) {
            $this->assertEquals('available', $court['status']);
            $this->assertNull($court['match']);
        }
    }

    public function test_auto_assign_puts_next_queue_players_on_court(): void
    {
        $session = $this->createSessionWithCourts(2, autoAssign: true);

        foreach (['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $activeCourts = collect($state['courts'])->where('status', 'in_match');

        $this->assertGreaterThanOrEqual(1, $activeCourts->count());
        $this->assertNotNull($activeCourts->first()['match']);
    }

    public function test_assign_next_puts_suggested_group_on_court(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign-next")
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $court = collect($after['courts'])->firstWhere('id', $courtId);
        $this->assertEquals('in_match', $court['status']);
        $this->assertNotNull($court['match']);
    }

    public function test_manual_assign_puts_players_on_court(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['P1', 'P2', 'P3', 'P4'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $playerIds = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->pluck('id')
            ->take(4)
            ->values()
            ->all();

        $courtId = $this->regularCourtId($state);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $court = collect($after['courts'])->firstWhere('id', $courtId);

        $this->assertEquals('in_match', $court['status']);
        $this->assertNotNull($court['match']);
        $this->assertEquals('loser', $after['session']['nextCourtQueue']);
    }

    public function test_finish_match_updates_queues_and_leaves_court_empty(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['A1', 'A2', 'B1', 'B2'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $playerIds = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->pluck('id')
            ->values()
            ->all();
        $courtId = $this->regularCourtId($state);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $court = collect($state['courts'])->firstWhere('id', $courtId);
        $this->assertNotNull($court);
        $match = $court['match'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$match['id']}/score", [
                'score_a' => 11,
                'score_b' => 5,
            ])
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $this->assertCount(2, $after['queues']['winner']);
        $this->assertCount(2, $after['queues']['loser']);
        $finishedCourt = collect($after['courts'])->firstWhere('id', $courtId);
        $this->assertEquals('available', $finishedCourt['status']);
        $this->assertNull($finishedCourt['match']);
    }

    public function test_auto_assign_fills_court_after_match_finishes(): void
    {
        $session = $this->createSessionWithCourts(2, autoAssign: true);

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'C3', 'C4'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $court = collect($state['courts'])
            ->first(fn (array $item) => $item['status'] === 'in_match'
                && ! ($item['isChallengeCourt'] ?? false));
        $this->assertNotNull($court);
        $matchId = $court['match']['id'];
        $courtId = $court['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 7,
            ])
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $refilled = collect($after['courts'])->firstWhere('id', $courtId);
        $this->assertEquals('in_match', $refilled['status']);
        $this->assertNotNull($refilled['match']);
    }

    public function test_end_session_generates_report_with_match_durations(): void
    {
        $session = $this->createSessionWithCourts(1);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/end")
            ->assertOk()
            ->assertJsonStructure([
                'report' => [
                    'totalMatches',
                    'durationMinutes',
                    'avgMatchDurationMinutes',
                    'matchSummaries',
                    'queueDistribution',
                    'courtUtilizationPercent',
                    'playerSummaries',
                ],
            ]);
    }

    public function test_skill_separated_session_report_handles_missing_winner_queue(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'match_mode' => 'skill_separated',
                'court_count' => 1,
            ]);

        $response->assertCreated();
        $sessionId = $response->json('session.id');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$sessionId}/end")
            ->assertOk()
            ->assertJsonPath('report.queueDistribution.winnersQueueSize', 0)
            ->assertJsonPath('report.queueDistribution.losersQueueSize', 0);
    }

    public function test_remove_player_from_court_swaps_in_next_queue_player(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $onCourtIds = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->take(4)
            ->pluck('id')
            ->values()
            ->all();
        $courtId = $this->regularCourtId($state);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $onCourtIds,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $court = collect($state['courts'])->firstWhere('id', $courtId);
        $removedName = $court['match']['teamA']['player1']['name'];
        $removeId = $court['match']['teamA']['player1']['id'];
        $nextUpName = $state['upNext'][0]['players'][0]['name'] ?? null;
        $this->assertNotNull($nextUpName);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/players/{$removeId}/remove")
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $activeCourt = collect($after['courts'])->firstWhere('id', $courtId);
        $this->assertEquals('in_match', $activeCourt['status']);
        $this->assertNotNull($activeCourt['match']);

        $courtPlayerNames = collect([
            $activeCourt['match']['teamA']['player1']['name'],
            $activeCourt['match']['teamA']['player2']['name'],
            $activeCourt['match']['teamB']['player1']['name'],
            $activeCourt['match']['teamB']['player2']['name'],
        ]);

        $this->assertFalse($courtPlayerNames->contains($removedName));
        $this->assertTrue($courtPlayerNames->contains($nextUpName));

        $loserNames = collect($after['queues']['loser'])->pluck('name');
        $this->assertTrue($loserNames->contains($removedName));
        $this->assertEquals(
            $removedName,
            $loserNames->last(),
            'Removed player should be at the end of the losers queue',
        );
    }

    public function test_admin_pin_required_for_mutations(): void
    {
        $this->postJson('/api/sessions')->assertUnauthorized();
    }

    public function test_toggle_auto_assign_during_session(): void
    {
        $session = $this->createSessionWithCourts(1);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/settings", [
                'auto_assign_enabled' => true,
            ])
            ->assertOk()
            ->assertJsonPath('session.autoAssignEnabled', true);
    }

    public function test_can_resize_court_count_during_active_session(): void
    {
        $session = $this->createSessionWithCourts(4);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/settings", [
                'court_count' => 2,
            ])
            ->assertOk()
            ->assertJsonPath('session.courtCount', 2);

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $this->assertCount(2, $state['courts']);
    }

    public function test_can_reduce_courts_clears_active_matches(): void
    {
        $session = $this->createSessionWithCourts(4, autoAssign: true);

        foreach (range(1, 16) as $index) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => "P{$index}"])
                ->assertCreated();
        }

        $before = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtFour = collect($before['courts'])->firstWhere('courtNumber', 4);
        $this->assertEquals('in_match', $courtFour['status']);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/settings", [
                'court_count' => 2,
            ])
            ->assertOk()
            ->assertJsonPath('session.courtCount', 2);

        $after = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $this->assertCount(2, $after['courts']);
        $this->assertEquals(
            'in_match',
            collect($after['courts'])->firstWhere('courtNumber', 2)['status'],
        );
    }

    public function test_live_state_endpoint_omits_heavy_fields_but_keeps_live_data(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['P1', 'P2', 'P3', 'P4'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $full = $this->getJson("/api/sessions/{$session->id}/state")->assertOk()->json();
        $live = $this->getJson("/api/sessions/{$session->id}/live")->assertOk()->json();

        $this->assertArrayHasKey('queues', $live);
        $this->assertArrayHasKey('courts', $live);
        $this->assertArrayHasKey('finishedMatchCount', $live);
        $this->assertSame([], $live['pendingPayments']);
        $this->assertSame($full['queues']['winner'], $live['queues']['winner']);
        $this->assertSame($full['session']['id'], $live['session']['id']);
    }

    public function test_move_queue_player_within_and_across_queues(): void
    {
        $session = $this->createSessionWithCourts(2);

        foreach (['Josh', 'Mac', 'Jacko', 'Ben'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $joshId = collect($state['queues']['winner'])->firstWhere('name', 'Josh')['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/queues/move", [
                'player_id' => $joshId,
                'queue_type' => 'winner',
                'position' => 2,
            ])
            ->assertOk();

        $afterReorder = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $this->assertEquals(
            ['Mac', 'Josh'],
            collect($afterReorder['queues']['winner'])->pluck('name')->all(),
        );

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/queues/move", [
                'player_id' => $joshId,
                'queue_type' => 'loser',
                'position' => 1,
            ])
            ->assertOk();

        $afterMove = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $this->assertEquals(['Mac'], collect($afterMove['queues']['winner'])->pluck('name')->all());
        $this->assertEquals(
            ['Josh', 'Jacko', 'Ben'],
            collect($afterMove['queues']['loser'])->pluck('name')->all(),
        );
    }

    private function createSessionWithCourts(int $courtCount, bool $autoAssign = false): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'court_count' => $courtCount,
                'auto_assign_enabled' => $autoAssign,
            ]);

        return PlaySession::query()->findOrFail($response->json('session.id'));
    }

    public function test_active_endpoint_returns_ok_when_no_session_running(): void
    {
        $this->getJson('/api/sessions/active')
            ->assertOk()
            ->assertJson([
                'active' => false,
                'message' => 'No active session',
            ]);
    }
}
