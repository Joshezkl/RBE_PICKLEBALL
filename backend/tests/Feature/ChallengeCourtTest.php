<?php

namespace Tests\Feature;

use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChallengeCourtTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_challenge_court_join_removes_players_from_regular_queues(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $alice = collect($state['challengeCourt']['eligiblePlayers'])
            ->firstWhere('name', 'Alice');
        $bob = collect($state['challengeCourt']['eligiblePlayers'])
            ->firstWhere('name', 'Bob');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/join", [
                'player_id' => $alice['id'],
                'partner_id' => $bob['id'],
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();

        $this->assertCount(1, $state['challengeCourt']['teams']);
        $this->assertEquals('Alice & Bob', $state['challengeCourt']['teams'][0]['displayName']);
        $this->assertCount(0, $state['queues']['winner']);
        $this->assertCount(2, $state['queues']['loser']);
        $this->assertFalse(
            collect($state['queues']['winner'])->pluck('name')->contains('Alice')
        );
        $this->assertFalse(
            collect($state['queues']['loser'])->pluck('name')->contains('Bob')
        );
    }

    public function test_challenge_court_assigns_fifo_teams_to_designated_court(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        if ($ccCourt['status'] !== 'in_match') {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
                ->assertOk();
            $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
            $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        }

        $this->assertEquals('in_match', $ccCourt['status']);
        $this->assertTrue($ccCourt['match']['isChallengeCourt']);
        $this->assertEquals('Alice', $ccCourt['match']['teamA']['player1']['name']);
        $this->assertEquals('Carol', $ccCourt['match']['teamB']['player1']['name']);
    }

    public function test_challenge_court_match_updates_rankings_and_history(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        if ($ccCourt['status'] !== 'in_match') {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
                ->assertOk();
            $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        }

        $matchId = collect($state['courts'])
            ->firstWhere('isChallengeCourt', true)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 7,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();

        $this->assertTrue($state['matchHistory'][0]['isChallengeCourt']);
        $alice = collect($state['queues']['winner'])
            ->concat($state['queues']['loser'])
            ->firstWhere('name', 'Alice');
        $this->assertNull($alice);

        $ccTeams = collect($state['challengeCourt']['teams']);
        $this->assertCount(2, $ccTeams);

        $idleTeam = $ccTeams->firstWhere('status', 'idle');
        $queuedTeam = $ccTeams->firstWhere('status', 'queued');
        $this->assertNotNull($idleTeam);
        $this->assertNotNull($queuedTeam);
        $this->assertEquals(1, $idleTeam['ccWins']);
        $this->assertEquals(0, $queuedTeam['ccWins']);

        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        $this->assertEquals('available', $ccCourt['status']);
        $this->assertNotNull($ccCourt['defendingTeam']);
        $this->assertTrue($ccCourt['canNextChallenger']);
    }

    public function test_finished_challenge_court_teams_rejoin_cc_queue_not_session_queues(): void
    {
        $session = $this->createSessionWithPlayers();

        foreach (['Eve', 'Frank'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');
        $this->joinTeam($session->id, 'Eve', 'Frank');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        if ($ccCourt['status'] !== 'in_match') {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
                ->assertOk();
            $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        }

        $matchId = collect($state['courts'])
            ->firstWhere('isChallengeCourt', true)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 7,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();

        foreach (['Alice', 'Bob', 'Carol', 'Dave'] as $name) {
            $inRegularQueue = collect($state['queues']['winner'])
                ->concat($state['queues']['loser'])
                ->contains('name', $name);
            $this->assertFalse($inRegularQueue, "{$name} should not be in a regular session queue");
        }

        $queuedTeams = collect($state['challengeCourt']['teams'])
            ->where('status', 'queued')
            ->values();

        $this->assertGreaterThanOrEqual(1, $queuedTeams->count());
        $this->assertTrue(
            collect($state['challengeCourt']['teams'])
                ->contains(fn (array $team) => $team['status'] === 'idle'),
        );
    }

    public function test_next_challenger_assigns_queued_team_against_one_zero_defender(): void
    {
        $session = $this->createSessionWithPlayers();

        foreach (['Eve', 'Frank'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');
        $this->joinTeam($session->id, 'Eve', 'Frank');

        $this->finishInitialCcMatch($session);

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        $this->assertTrue($ccCourt['canNextChallenger']);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        $this->assertEquals('in_match', $ccCourt['status']);
        $this->assertEquals('Eve', $ccCourt['match']['teamB']['player1']['name']);
        $this->assertEquals('Alice', $ccCourt['match']['teamA']['player1']['name']);
    }

    public function test_two_zero_champion_requeues_and_starts_new_initial_match(): void
    {
        $session = $this->createSessionWithPlayers();

        foreach (['Eve', 'Frank', 'Grace', 'Henry'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');
        $this->joinTeam($session->id, 'Eve', 'Frank');
        $this->joinTeam($session->id, 'Grace', 'Henry');

        $this->finishInitialCcMatch($session);
        $this->assignNextChallenger($session);
        $this->scoreCurrentCcMatch($session, 11, 8);

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccTeams = collect($state['challengeCourt']['teams']);
        $this->assertTrue(
            $ccTeams->contains(
                fn (array $team) => $team['displayName'] === 'Alice & Bob'
                    && $team['status'] === 'queued',
            ),
        );
        $this->assertPlayersNotInSessionQueues($state, ['Alice', 'Bob', 'Eve', 'Frank']);

        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        $this->assertEquals('in_match', $ccCourt['status']);

        $playingNames = collect([
            $ccCourt['match']['teamA']['player1']['name'],
            $ccCourt['match']['teamB']['player1']['name'],
        ]);
        $this->assertTrue($playingNames->contains('Carol'));
        $this->assertTrue($playingNames->contains('Grace'));
    }

    public function test_challenger_win_replaces_defender_and_stays_on_court(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $this->finishInitialCcMatch($session);
        $this->assignNextChallenger($session);
        $this->scoreCurrentCcMatch($session, 7, 11);

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccTeams = collect($state['challengeCourt']['teams']);
        $this->assertTrue(
            $ccTeams->contains(
                fn (array $team) => $team['displayName'] === 'Alice & Bob'
                    && $team['status'] === 'queued',
            ),
        );
        $this->assertTrue(
            $ccTeams->contains(
                fn (array $team) => $team['displayName'] === 'Carol & Dave'
                    && $team['status'] === 'idle'
                    && $team['ccWins'] === 1,
            ),
        );
        $this->assertPlayersNotInSessionQueues($state, ['Alice', 'Bob', 'Carol', 'Dave']);

        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);
        $this->assertEquals('available', $ccCourt['status']);
        $this->assertEquals('Carol & Dave', $ccCourt['defendingTeam']['displayName']);
        $this->assertEquals(1, $ccCourt['defendingTeam']['ccWins']);
        $this->assertTrue($ccCourt['canNextChallenger']);
    }

    public function test_next_challenger_available_when_defender_one_zero_and_queue_has_team(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $this->finishInitialCcMatch($session);
        $this->assignNextChallenger($session);
        $this->scoreCurrentCcMatch($session, 7, 11);

        foreach (['Eve', 'Frank'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }
        $this->joinTeam($session->id, 'Eve', 'Frank');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->assertEquals('Carol & Dave', $ccCourt['defendingTeam']['displayName']);
        $this->assertTrue($ccCourt['canNextChallenger']);
    }

    public function test_return_team_to_session_rejoins_regular_queues(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $teamId = $state['challengeCourt']['teams'][0]['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/teams/{$teamId}/return")
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();

        $this->assertCount(0, $state['challengeCourt']['teams']);
        $allQueued = collect($state['queues']['winner'])
            ->concat($state['queues']['loser'])
            ->pluck('name');
        $this->assertTrue($allQueued->contains('Alice'));
        $this->assertTrue($allQueued->contains('Bob'));
    }

    public function test_return_missing_challenge_court_team_returns_clear_error(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/teams/999/return")
            ->assertStatus(422)
            ->assertJson([
                'message' => 'Challenge Court team not found. It may have already been removed.',
            ]);
    }

    public function test_challenge_court_can_be_unassigned_from_court(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/sessions/{$session->id}/challenge-court/configure", [
                'court_numbers' => [],
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();

        $this->assertSame([], $state['challengeCourt']['courtNumbers']);
        $this->assertFalse($state['challengeCourt']['isOpen']);
        $this->assertFalse(
            collect($state['courts'])->contains(fn (array $court) => $court['isChallengeCourt']),
        );
    }

    public function test_challenge_court_assign_next_fails_when_closed(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/close")
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
            ->assertStatus(422)
            ->assertJson(['message' => 'Challenge Court is not open']);
    }

    public function test_challenge_court_does_not_auto_assign_when_session_auto_assign_disabled(): void
    {
        $session = $this->createSessionWithPlayers();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->assertEquals('available', $ccCourt['status']);
        $this->assertNull($ccCourt['match']);
        $this->assertTrue(
            collect($state['challengeCourt']['teams'])
                ->every(fn (array $team) => $team['status'] === 'queued'),
        );
    }

    public function test_challenge_court_auto_assigns_when_session_auto_assign_enabled(): void
    {
        $session = $this->createSessionWithPlayers(autoAssign: true);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/challenge-court/open")
            ->assertOk();

        $this->joinTeam($session->id, 'Alice', 'Bob');
        $this->joinTeam($session->id, 'Carol', 'Dave');

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->assertEquals('in_match', $ccCourt['status']);
        $this->assertTrue($ccCourt['match']['isChallengeCourt']);
    }

    public function test_regular_auto_assign_skips_challenge_courts(): void
    {
        $session = $this->createSessionWithPlayers(autoAssign: true);

        foreach (['Eve', 'Frank', 'Grace', 'Henry'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name])
                ->assertCreated();
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->assertEquals('available', $ccCourt['status']);
        $this->assertGreaterThanOrEqual(
            1,
            collect($state['courts'])->where('status', 'in_match')->count()
        );
    }

    private function createSessionWithPlayers(bool $autoAssign = false): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'CC Test',
                'court_count' => 4,
                'play_format' => 'doubles',
                'auto_assign_enabled' => $autoAssign,
            ]);

        $response->assertCreated();
        $sessionId = $response->json('session.id');

        foreach (['Alice', 'Bob', 'Carol', 'Dave'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$sessionId}/players", ['name' => $name])
                ->assertCreated();
        }

        return PlaySession::query()->findOrFail($sessionId);
    }

    private function joinTeam(int $sessionId, string $player1, string $player2): void
    {
        $state = $this->getJson("/api/sessions/{$sessionId}/state")->json();
        $p1 = collect($state['challengeCourt']['eligiblePlayers'])
            ->firstWhere('name', $player1);
        $p2 = collect($state['challengeCourt']['eligiblePlayers'])
            ->firstWhere('name', $player2);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$sessionId}/challenge-court/join", [
                'player_id' => $p1['id'],
                'partner_id' => $p2['id'],
            ])
            ->assertOk();
    }

    private function finishInitialCcMatch(PlaySession $session): void
    {
        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        if ($ccCourt['status'] !== 'in_match') {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
                ->assertOk();
        }

        $this->scoreCurrentCcMatch($session, 11, 7);
    }

    private function assignNextChallenger(PlaySession $session): void
    {
        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $ccCourt = collect($state['courts'])->firstWhere('isChallengeCourt', true);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$ccCourt['id']}/assign-challenge-next")
            ->assertOk();
    }

    private function scoreCurrentCcMatch(PlaySession $session, int $scoreA, int $scoreB): void
    {
        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $matchId = collect($state['courts'])
            ->firstWhere('isChallengeCourt', true)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => $scoreA,
                'score_b' => $scoreB,
            ])
            ->assertOk();
    }

    /**
     * @param  array<int, string>  $names
     */
    private function assertPlayersNotInSessionQueues(array $state, array $names): void
    {
        $queuedNames = collect($state['queues']['winner'])
            ->concat($state['queues']['loser'])
            ->pluck('name');

        foreach ($names as $name) {
            $this->assertFalse(
                $queuedNames->contains($name),
                "{$name} should not be in a regular session queue",
            );
        }
    }
}
