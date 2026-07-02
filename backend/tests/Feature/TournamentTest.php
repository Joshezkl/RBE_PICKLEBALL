<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TournamentTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_create_tournament_seeds_full_category_catalog(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Summer Open',
                'group_count' => 4,
                'categories' => [
                    'mens_doubles_open:beginner',
                    'mens_doubles_open:novice',
                    'mixed_doubles_40_plus:intermediate',
                ],
            ]);

        $response->assertCreated();
        $response->assertJsonPath('tournament.name', 'Summer Open');
        $response->assertJsonPath('tournament.groupCount', 4);
        $this->assertCount(96, $response->json('availableCategories'));
        $this->assertCount(3, $response->json('categories'));
    }

    public function test_admin_registers_doubles_pair(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Pair Registration',
                'group_count' => 2,
                'categories' => ['mens_doubles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_doubles_open:intermediate';

        $playerOne = $this->createMalePlayer('Doubles One', 'intermediate');
        $playerTwo = $this->createMalePlayer('Doubles Two', 'intermediate');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/categories/{$categoryKey}/teams", [
                'player_ids' => [$playerOne, $playerTwo],
            ])
            ->assertOk();

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/tournaments/{$tournamentId}")
            ->assertOk()
            ->json();

        $this->assertCount(1, $state['categories'][0]['teams']);
        $this->assertEquals(
            'Doubles One / Doubles Two',
            $state['categories'][0]['teams'][0]['displayName'],
        );
        $this->assertNull($state['categories'][0]['teams'][0]['groupKey']);
    }

    public function test_start_randomly_assigns_teams_to_groups(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Random Groups',
                'group_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $groupKeys = collect($state['categories'][0]['teams'])
            ->pluck('groupKey')
            ->filter()
            ->unique()
            ->values()
            ->all();

        $this->assertCount(2, $groupKeys);
        $this->assertEquals(2, collect($state['categories'][0]['teams'])->where('groupKey', 'A')->count());
        $this->assertEquals(2, collect($state['categories'][0]['teams'])->where('groupKey', 'B')->count());
    }

    public function test_round_robin_rejects_tie_scores(): void
    {
        $tournamentId = $this->createStartedSinglesTournament();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matchId = $state['categories'][0]['matches'][0]['id'];

        $this->prepareMatchForScoring($tournamentId, $matchId);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 11,
            ])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Ties are not allowed — enter a winning score');
    }

    public function test_group_round_robin_advances_one_per_group_to_final(): void
    {
        $tournamentId = $this->createStartedSinglesTournament(groupCount: 2);

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matches = collect($state['categories'][0]['matches'])
            ->where('phase', 'round_robin');

        $this->assertCount(2, $matches);

        foreach ($matches as $match) {
            $this->scoreMatch($tournamentId, $match['id'], 11, 5);
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();

        $this->assertEquals('single_elimination', $after['categories'][0]['phase']);
        $elimMatches = collect($after['categories'][0]['matches'])
            ->where('phase', 'single_elimination');
        $this->assertCount(1, $elimMatches);
    }

    public function test_standings_use_points_then_head_to_head_tiebreaker_within_group(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Tiebreaker Test',
                'group_count' => 1,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Alex', 'Blake', 'Casey'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matches = $state['categories'][0]['matches'];
        $byTeams = collect($matches)->keyBy(fn ($m) => "{$m['teamA']['displayName']}-{$m['teamB']['displayName']}");

        $this->scoreMatch($tournamentId, $byTeams['Alex-Blake']['id'], 11, 3);
        $this->scoreMatch($tournamentId, $byTeams['Blake-Casey']['id'], 11, 3);
        $this->scoreMatch($tournamentId, $byTeams['Alex-Casey']['id'], 5, 11);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $standings = $after['categories'][0]['groups'][0]['standings'];

        $this->assertEquals('Alex', $standings[0]['displayName']);
        $this->assertEquals('Blake', $standings[1]['displayName']);
        $this->assertEquals('Casey', $standings[2]['displayName']);
    }

    public function test_head_to_head_breaks_standings_when_wins_and_points_are_tied(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Head To Head',
                'group_count' => 1,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Taylor', 'Jordan', 'Riley'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matches = $state['categories'][0]['matches'];
        $byTeams = collect($matches)->keyBy(fn ($m) => "{$m['teamA']['displayName']}-{$m['teamB']['displayName']}");

        $this->scoreMatch($tournamentId, $byTeams['Taylor-Jordan']['id'], 11, 9);
        $this->scoreMatch($tournamentId, $byTeams['Jordan-Riley']['id'], 11, 9);
        $this->scoreMatch($tournamentId, $byTeams['Taylor-Riley']['id'], 9, 11);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $standings = $after['categories'][0]['groups'][0]['standings'];

        $this->assertEquals('Taylor', $standings[0]['displayName']);
        $this->assertEquals('Jordan', $standings[1]['displayName']);
        $this->assertEquals('Riley', $standings[2]['displayName']);
    }

    public function test_single_group_crowns_round_robin_winner(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Single Group',
                'group_count' => 1,
                'categories' => ['mens_singles_open:beginner'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:beginner';

        foreach (['P1', 'P2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'beginner'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matchId = $state['categories'][0]['matches'][0]['id'];

        $this->scoreMatch($tournamentId, $matchId, 11, 4);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();

        $this->assertEquals('completed', $after['categories'][0]['phase']);
        $champion = collect($after['categories'][0]['teams'])->firstWhere('status', 'champion');
        $this->assertNotNull($champion);

        $runnerUp = collect($after['categories'][0]['teams'])->firstWhere('status', 'runner_up');
        $this->assertNotNull($runnerUp);

        $placements = $after['categories'][0]['placements'];
        $this->assertCount(2, $placements);
        $this->assertEquals(1, $placements[0]['place']);
        $this->assertEquals(2, $placements[1]['place']);
    }

    public function test_rejects_wrong_skill_level_for_category(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Skill Gate',
                'categories' => ['womens_singles_35_plus:advanced'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $playerId = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/players', [
                'name' => 'Wrong Skill',
                'skill_level' => 'beginner',
                'gender' => 'female',
            ])
            ->json('player.id');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('womens_singles_35_plus:advanced').'/teams',
                ['player_ids' => [$playerId]],
            )
            ->assertStatus(422);
    }

    public function test_four_groups_advance_to_semifinals_and_final_bracket(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Bracket Four',
                'group_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        for ($i = 1; $i <= 8; $i++) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer("Player{$i}", 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $rrMatches = collect($state['categories'][0]['matches'])
            ->where('phase', 'round_robin');

        $this->assertCount(4, $rrMatches);

        foreach ($rrMatches as $match) {
            $this->scoreMatch($tournamentId, $match['id'], 11, 4);
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $bracket = $after['categories'][0]['bracket'];

        $this->assertEquals('single_elimination', $after['categories'][0]['phase']);
        $this->assertCount(2, $bracket['rounds']);

        $semiOneId = $bracket['rounds'][0]['matches'][0]['id'];
        $semiTwoId = $bracket['rounds'][0]['matches'][1]['id'];
        $finalId = $bracket['rounds'][1]['matches'][0]['id'];

        $this->scoreMatch($tournamentId, $semiOneId, 11, 6);
        $this->scoreMatch($tournamentId, $semiTwoId, 11, 8);

        $afterSemis = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $thirdPlace = $afterSemis['categories'][0]['thirdPlaceMatch'];
        $this->assertNotNull($thirdPlace);

        $this->scoreMatch($tournamentId, $finalId, 11, 9);
        $this->scoreMatch($tournamentId, $thirdPlace['id'], 11, 7);

        $done = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('completed', $done['categories'][0]['phase']);

        $placements = $done['categories'][0]['placements'];
        $this->assertCount(3, $placements);
        $this->assertEquals(1, $placements[0]['place']);
        $this->assertEquals(2, $placements[1]['place']);
        $this->assertEquals(3, $placements[2]['place']);
    }

    public function test_backfills_legacy_placements_from_finished_matches(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Legacy Backfill',
                'group_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        for ($i = 1; $i <= 8; $i++) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer("Legacy{$i}", 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $bracket = $after['categories'][0]['bracket'];
        $semiOneId = $bracket['rounds'][0]['matches'][0]['id'];
        $semiTwoId = $bracket['rounds'][0]['matches'][1]['id'];
        $finalId = $bracket['rounds'][1]['matches'][0]['id'];

        $this->scoreMatch($tournamentId, $semiOneId, 11, 6);
        $this->scoreMatch($tournamentId, $semiTwoId, 11, 8);

        $afterSemis = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $thirdPlaceId = $afterSemis['categories'][0]['thirdPlaceMatch']['id'];

        $this->scoreMatch($tournamentId, $finalId, 11, 9);
        $this->scoreMatch($tournamentId, $thirdPlaceId, 11, 7);

        $completed = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('completed', $completed['categories'][0]['phase']);
        $championId = collect($completed['categories'][0]['teams'])
            ->firstWhere('status', 'champion')['id'];

        \App\Models\TournamentTeam::query()
            ->where('tournament_id', $tournamentId)
            ->where('id', '!=', $championId)
            ->update(['status' => 'eliminated']);

        $backfilled = $this->getJson("/api/tournaments/{$tournamentId}")
            ->assertOk()
            ->json();

        $placements = $backfilled['categories'][0]['placements'];
        $this->assertGreaterThanOrEqual(2, count($placements));
        $this->assertEquals(1, $placements[0]['place']);
        $this->assertEquals(2, $placements[1]['place']);

        $runnerUp = collect($backfilled['categories'][0]['teams'])
            ->firstWhere('status', 'runner_up');
        $this->assertNotNull($runnerUp);

        if (count($placements) === 3) {
            $this->assertEquals(3, $placements[2]['place']);
            $this->assertNotNull(
                collect($backfilled['categories'][0]['teams'])->firstWhere('status', 'third')
            );
        }
    }

    public function test_completed_legacy_tournament_gets_scheduled_third_place_match(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Legacy Bronze',
                'group_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        for ($i = 1; $i <= 8; $i++) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer("Bronze{$i}", 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $bracket = $after['categories'][0]['bracket'];
        $this->scoreMatch($tournamentId, $bracket['rounds'][0]['matches'][0]['id'], 11, 6);
        $this->scoreMatch($tournamentId, $bracket['rounds'][0]['matches'][1]['id'], 11, 8);

        $afterSemis = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $thirdPlaceId = $afterSemis['categories'][0]['thirdPlaceMatch']['id'];

        $this->scoreMatch($tournamentId, $bracket['rounds'][1]['matches'][0]['id'], 11, 9);
        $this->scoreMatch($tournamentId, $thirdPlaceId, 11, 7);

        $completed = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('completed', $completed['categories'][0]['phase']);
        $championId = collect($completed['categories'][0]['teams'])
            ->firstWhere('status', 'champion')['id'];

        \App\Models\TournamentTeam::query()
            ->where('tournament_id', $tournamentId)
            ->where('id', '!=', $championId)
            ->update(['status' => 'eliminated']);

        \App\Models\TournamentMatch::query()
            ->where('tournament_id', $tournamentId)
            ->where('phase', 'third_place')
            ->delete();

        $reopened = $this->getJson("/api/tournaments/{$tournamentId}")
            ->assertOk()
            ->json();

        $this->assertEquals(
            'single_elimination',
            $reopened['categories'][0]['phase']
        );
        $this->assertNotNull($reopened['categories'][0]['thirdPlaceMatch']);
        $thirdPlace = $reopened['categories'][0]['thirdPlaceMatch'];
        $this->assertEquals('scheduled', $thirdPlace['status']);
        $this->assertNull($thirdPlace['courtNumber']);
        $this->assertNotNull($thirdPlace['teamA']);
        $this->assertNotNull($thirdPlace['teamB']);
    }

    public function test_rejects_start_when_group_has_fewer_than_two_teams(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Incomplete Groups',
                'group_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        $this->registerTeam($tournamentId, $categoryKey, [
            $this->createMalePlayer('Only One', 'intermediate'),
        ]);
        $this->registerTeam($tournamentId, $categoryKey, [
            $this->createMalePlayer('Only Two', 'intermediate'),
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertStatus(422);
    }

    private function createStartedSinglesTournament(int $groupCount = 2): int
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Singles Event',
                'group_count' => $groupCount,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Player A', 'Player B', 'Player C', 'Player D'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        return $tournamentId;
    }

    private function createTournamentWithCategory(string $categoryKey): int
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Registration Test',
                'group_count' => 2,
                'categories' => [$categoryKey],
            ])
            ->assertCreated();

        return (int) $response->json('tournament.id');
    }

    private function registerTeam(
        int $tournamentId,
        string $categoryKey,
        array $playerIds,
    ): void {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode($categoryKey).'/teams',
                ['player_ids' => $playerIds],
            )
            ->assertOk();
    }

    private function createMalePlayer(string $name, string $skillLevel): int
    {
        return $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/players', [
                'name' => $name,
                'skill_level' => $skillLevel,
                'gender' => 'male',
            ])
            ->json('player.id');
    }

    private function scoreMatch(int $tournamentId, int $matchId, int $scoreA, int $scoreB): void
    {
        $this->prepareMatchForScoring($tournamentId, $matchId);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$matchId}/score", [
                'score_a' => $scoreA,
                'score_b' => $scoreB,
            ])
            ->assertOk();
    }

    private function prepareMatchForScoring(int $tournamentId, int $matchId): void
    {
        $match = \App\Models\TournamentMatch::query()->findOrFail($matchId);

        if ($match->status === 'on_court') {
            return;
        }

        if ($match->status !== 'scheduled') {
            return;
        }

        if ($match->court_number !== null) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/tournaments/{$tournamentId}/matches/{$matchId}/activate-court")
                ->assertOk();

            return;
        }

        $match->update([
            'status' => 'on_court',
            'court_number' => 1,
        ]);
    }

    private function assignMatchToCourt(
        int $tournamentId,
        int $matchId,
        int $courtNumber,
    ): void {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$matchId}/assign-court", [
                'court_number' => $courtNumber,
            ])
            ->assertOk();
    }

    /**
     * @param  array<string, mixed>  $state
     */
    private function assignPreferredMatchesToCourts(int $tournamentId, array $state): void
    {
        $upNext = collect($state['display']['upNext']);
        $assignedMatchIds = [];

        foreach ($state['display']['courts'] as $court) {
            $preferredGroup = $court['preferredGroupKey'] ?? null;
            if ($preferredGroup === null) {
                continue;
            }

            $match = $upNext
                ->reject(fn (array $entry) => in_array($entry['id'], $assignedMatchIds, true))
                ->firstWhere('groupKey', $preferredGroup);

            if ($match === null) {
                continue;
            }

            $this->assignMatchToCourt($tournamentId, $match['id'], $court['courtNumber']);
            $assignedMatchIds[] = $match['id'];
        }
    }

    public function test_delete_tournament_removes_it_from_list(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Delete Me',
                'group_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/tournaments/{$tournamentId}")
            ->assertNoContent();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson('/api/tournaments')
            ->assertOk();

        $ids = collect(
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->getJson('/api/tournaments')
                ->json('tournaments')
        )->pluck('id');

        $this->assertFalse($ids->contains($tournamentId));

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/tournaments/{$tournamentId}")
            ->assertNotFound();
    }

    public function test_start_leaves_courts_open_for_manual_assignment(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Court Assign',
                'group_count' => 4,
                'court_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'D1', 'D2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk()
            ->json();

        $courts = collect($state['display']['courts']);
        $this->assertCount(4, $courts);
        $this->assertEquals(4, $courts->where('status', 'available')->count());
        $this->assertNotEmpty($state['display']['upNext']);
    }

    public function test_can_reduce_court_count_during_live_tournament(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Resize Courts',
                'group_count' => 2,
                'court_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/tournaments/{$tournamentId}", [
                'court_count' => 2,
            ])
            ->assertOk()
            ->json();

        $this->assertEquals(2, $state['tournament']['courtCount']);
        $this->assertCount(2, $state['display']['courts']);
    }

    public function test_reduce_court_count_clears_assignments_without_auto_reassign(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Resize With Active Courts',
                'group_count' => 4,
                'court_count' => 4,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'D1', 'D2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assignMatchToCourt(
            $tournamentId,
            $state['display']['upNext'][0]['id'],
            1,
        );

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/tournaments/{$tournamentId}", [
                'court_count' => 2,
            ])
            ->assertOk()
            ->json();

        $this->assertEquals(2, $state['tournament']['courtCount']);
        $courts = collect($state['display']['courts']);
        $this->assertCount(2, $courts);
        $this->assertTrue(
            $courts->every(fn (array $court) => $court['status'] === 'available'),
        );

        $upNextGroups = collect($state['display']['upNext'])->pluck('groupKey')->all();
        $this->assertNotContains('C', $upNextGroups);
        $this->assertNotContains('D', $upNextGroups);
        $this->assertTrue(
            collect($upNextGroups)->every(fn (string $group) => in_array($group, ['A', 'B'], true)),
        );
    }

    public function test_later_groups_wait_until_earlier_batch_finishes_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Group Batch Priority',
                'group_count' => 4,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'D1', 'D2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk()
            ->json();

        $upNextGroups = collect($state['display']['upNext'])->pluck('groupKey')->all();
        $this->assertNotContains('C', $upNextGroups);
        $this->assertNotContains('D', $upNextGroups);

        $courtGroups = collect($state['display']['courts'])
            ->pluck('match.groupKey')
            ->filter()
            ->all();
        $this->assertSame([], $courtGroups);
    }

    public function test_scoring_frees_court_without_auto_assigning_next_match(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Court Refill',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $before = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOneMatchId = $before['display']['upNext'][0]['id'];
        $this->assignMatchToCourt($tournamentId, $courtOneMatchId, 1);

        $this->scoreMatch($tournamentId, $courtOneMatchId, 11, 5);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOne = collect($after['display']['courts'])->firstWhere('courtNumber', 1);

        $this->assertEquals('available', $courtOne['status']);
        $this->assertNull($courtOne['match']);
    }

    public function test_activate_court_marks_match_as_playing(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Activate Court',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $matchId = $state['display']['upNext'][0]['id'];
        $this->assignMatchToCourt($tournamentId, $matchId, 1);

        \App\Models\TournamentMatch::query()
            ->where('id', $matchId)
            ->update(['status' => 'scheduled']);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$matchId}/activate-court")
            ->assertOk();

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOne = collect($after['display']['courts'])->firstWhere('courtNumber', 1);

        $this->assertEquals('in_match', $courtOne['status']);
        $this->assertTrue($courtOne['match']['isActive']);
    }

    public function test_admin_can_manually_assign_waiting_match_to_open_court(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Manual Assign',
                'group_count' => 2,
                'court_count' => 4,
                'categories' => ['mens_doubles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_doubles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
                $this->createMalePlayer($name.'P', 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $waitingMatchId = collect($state['display']['upNext'])->first()['id'];

        $this->assignMatchToCourt($tournamentId, $waitingMatchId, 1);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOne = collect($after['display']['courts'])->firstWhere('courtNumber', 1);

        $this->assertEquals('in_match', $courtOne['status']);
        $this->assertEquals($waitingMatchId, $courtOne['match']['id']);
    }

    public function test_courts_expose_preferred_group_by_court_number(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Court Group Priority',
                'group_count' => 4,
                'court_count' => 4,
                'categories' => ['mens_doubles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_doubles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
                $this->createMalePlayer($name.'P', 'intermediate'),
            ]);
        }

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk()
            ->json();

        $courts = collect($state['display']['courts']);
        $this->assertEquals('A', $courts->firstWhere('courtNumber', 1)['preferredGroupKey']);
        $this->assertEquals('B', $courts->firstWhere('courtNumber', 2)['preferredGroupKey']);
        $this->assertEquals('C', $courts->firstWhere('courtNumber', 3)['preferredGroupKey']);
        $this->assertEquals('D', $courts->firstWhere('courtNumber', 4)['preferredGroupKey']);
    }

    public function test_manual_assign_rejects_wrong_group_when_preferred_group_has_matches(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Court Group Guard',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $groupBMatchId = collect($state['display']['upNext'])
            ->firstWhere('groupKey', 'B')['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$groupBMatchId}/assign-court", [
                'court_number' => 1,
            ])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Court 1 is reserved for Group A while that group still has matches waiting.');
    }

    public function test_admin_can_replace_court_match_before_scoring(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Replace Court Match',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $firstMatchId = collect($state['display']['upNext'])
            ->firstWhere('groupKey', 'A')['id'];
        $secondMatchId = collect($state['display']['upNext'])
            ->where('groupKey', 'A')
            ->skip(1)
            ->first()['id'];

        $this->assignMatchToCourt($tournamentId, $firstMatchId, 1);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/matches/{$secondMatchId}/replace-court", [
                'court_number' => 1,
            ])
            ->assertOk();

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOne = collect($after['display']['courts'])->firstWhere('courtNumber', 1);

        $this->assertEquals('in_match', $courtOne['status']);
        $this->assertEquals($secondMatchId, $courtOne['match']['id']);

        $returnedToQueue = collect($after['display']['upNext'])
            ->contains(fn (array $entry) => $entry['id'] === $firstMatchId);
        $this->assertTrue($returnedToQueue);
    }

    public function test_up_next_lists_waiting_matches_when_all_courts_are_full(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Up Next Queue',
                'group_count' => 2,
                'court_count' => 4,
                'categories' => ['mens_doubles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_doubles_open:intermediate';

        foreach ([
            'A1', 'A2', 'A3', 'A4',
            'B1', 'B2', 'B3', 'B4',
        ] as $index => $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer("{$name}a", 'intermediate'),
                $this->createMalePlayer("{$name}b", 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assignPreferredMatchesToCourts($tournamentId, $state);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $upNext = $after['display']['upNext'];

        $this->assertNotEmpty($upNext);
        $this->assertFalse($upNext[0]['isReady']);
    }

    public function test_up_next_lists_ready_matches_before_waiting_matches(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Up Next Ready First',
                'group_count' => 1,
                'court_count' => 1,
                'categories' => ['mens_singles_open:beginner'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:beginner';

        foreach (['A1', 'A2', 'A3', 'A4', 'A5', 'A6'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'beginner'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assignMatchToCourt($tournamentId, $state['display']['upNext'][0]['id'], 1);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $upNext = $after['display']['upNext'];

        $this->assertNotEmpty($upNext);

        $readyCount = collect($upNext)->where('isReady', true)->count();
        $waitingCount = collect($upNext)->where('isReady', false)->count();
        $this->assertGreaterThan(0, $readyCount);
        $this->assertGreaterThan(0, $waitingCount);

        $seenWaiting = false;
        foreach ($upNext as $entry) {
            if (! $entry['isReady']) {
                $seenWaiting = true;
            }

            if ($seenWaiting) {
                $this->assertFalse($entry['isReady']);
            }
        }

        $this->assertTrue($upNext[0]['isReady']);
    }

    public function test_scoring_leaves_court_open_with_rested_matches_in_up_next(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Rest Scheduling',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $before = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $firstMatchId = $before['display']['upNext'][0]['id'];
        $this->assignMatchToCourt($tournamentId, $firstMatchId, 1);

        $this->scoreMatch($tournamentId, $firstMatchId, 11, 4);

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $courtOne = collect($after['display']['courts'])->firstWhere('courtNumber', 1);

        $this->assertEquals('available', $courtOne['status']);
        $this->assertNull($courtOne['match']);
        $this->assertTrue(collect($after['display']['upNext'])->contains('isReady', true));
    }

    public function test_round_robin_matches_are_scheduled_in_rest_friendly_rounds(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'RR Rounds',
                'group_count' => 1,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['P1', 'P2', 'P3', 'P4'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $matches = $this->getJson("/api/tournaments/{$tournamentId}")
            ->json('categories.0.matches');

        $roundIndexes = collect($matches)->pluck('roundIndex')->unique()->sort()->values()->all();

        $this->assertEquals([0, 1, 2], $roundIndexes);

        $roundZeroTeams = collect($matches)
            ->where('roundIndex', 0)
            ->flatMap(fn ($match) => [
                $match['teamA']['displayName'],
                $match['teamB']['displayName'],
            ])
            ->unique()
            ->count();

        $this->assertEquals(4, $roundZeroTeams);
    }

    public function test_active_tournament_endpoint_returns_live_tournament(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Live Board',
                'group_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['P1', 'P2', 'P3', 'P4'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $this->getJson('/api/tournaments/active')
            ->assertOk()
            ->assertJsonPath('tournament.id', $tournamentId);
    }

    public function test_active_tournament_endpoint_includes_final_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Final RR Live',
                'group_count' => 3,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Mac', 'Ben', 'Josh', 'Ivy', 'Kai', 'Leo'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $this->getJson('/api/tournaments/active')
            ->assertOk()
            ->assertJsonPath('tournament.id', $tournamentId)
            ->assertJsonPath('tournament.status', 'final_round_robin');
    }

    public function test_three_advancers_use_final_round_robin_instead_of_bracket(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Final Three',
                'group_count' => 3,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Mac', 'Ben', 'Josh', 'Ivy', 'Kai', 'Leo'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $category = $after['categories'][0];

        $this->assertEquals('final_round_robin', $category['phase']);
        $this->assertNull($category['bracket']);

        $finalMatches = collect($category['matches'])
            ->where('phase', 'final_round_robin')
            ->values();
        $this->assertCount(3, $finalMatches);

        $finalGroup = collect($category['groups'])->firstWhere('key', 'final');
        $this->assertNotNull($finalGroup);
        $this->assertCount(3, $finalGroup['matches']);

        foreach ($finalMatches as $match) {
            $this->scoreMatch($tournamentId, $match['id'], 11, 5);
        }

        $done = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('completed', $done['categories'][0]['phase']);

        $placements = $done['categories'][0]['placements'];
        $this->assertCount(3, $placements);
        $this->assertEquals(1, $placements[0]['place']);
        $this->assertEquals(2, $placements[1]['place']);
        $this->assertEquals(3, $placements[2]['place']);

        $teams = $done['categories'][0]['teams'];
        $this->assertNotNull(collect($teams)->firstWhere('status', 'champion'));
        $this->assertNotNull(collect($teams)->firstWhere('status', 'runner_up'));
        $this->assertNotNull(collect($teams)->firstWhere('status', 'third'));
    }

    public function test_final_round_robin_crowns_two_and_zero_record(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Final Three Clear',
                'group_count' => 3,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        $players = [];
        foreach (['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo', 'Foxtrot'] as $name) {
            $players[$name] = $this->createMalePlayer($name, 'intermediate');
            $this->registerTeam($tournamentId, $categoryKey, [$players[$name]]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 2);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $advancers = collect($after['categories'][0]['teams'])
            ->where('status', 'active')
            ->values();
        $this->assertCount(3, $advancers);

        $finalMatches = collect($after['categories'][0]['matches'])
            ->where('phase', 'final_round_robin')
            ->values();

        $champion = $advancers[0];
        foreach ($finalMatches as $match) {
            $isChampionTeamA = ($match['teamA']['id'] ?? null) === $champion['id'];
            $isChampionTeamB = ($match['teamB']['id'] ?? null) === $champion['id'];
            if ($isChampionTeamA) {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            } elseif ($isChampionTeamB) {
                $this->scoreMatch($tournamentId, $match['id'], 4, 11);
            } else {
                $this->scoreMatch($tournamentId, $match['id'], 11, 8);
            }
        }

        $done = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $championTeam = collect($done['categories'][0]['teams'])
            ->firstWhere('status', 'champion');
        $this->assertEquals($champion['id'], $championTeam['id']);
        $this->assertEquals(2, $championTeam['wins']);
        $this->assertEquals(0, $championTeam['losses']);
    }

    public function test_single_group_with_three_teams_uses_final_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Single Group Three',
                'group_count' => 1,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Mac', 'Ben', 'Josh'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('final_round_robin', $after['categories'][0]['phase']);
        $this->assertNull($after['categories'][0]['bracket']);
        $this->assertCount(
            3,
            collect($after['categories'][0]['matches'])->where('phase', 'final_round_robin')
        );
    }

    public function test_legacy_three_team_bye_bracket_is_repaired_on_state_load(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Repair Bracket',
                'group_count' => 3,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Mac', 'Ben', 'Josh', 'Ivy', 'Kai', 'Leo'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('final_round_robin', $after['categories'][0]['phase']);

        $finalMatches = collect($after['categories'][0]['matches'])
            ->where('phase', 'final_round_robin')
            ->values();
        $this->assertCount(3, $finalMatches);

        $advancerIds = $finalMatches
            ->flatMap(fn (array $match) => [$match['teamA']['id'], $match['teamB']['id']])
            ->unique()
            ->values();
        $this->assertCount(3, $advancerIds);

        $category = \App\Models\TournamentCategory::query()
            ->where('tournament_id', $tournamentId)
            ->firstOrFail();

        \App\Models\TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'final_round_robin')
            ->delete();

        \App\Models\TournamentMatch::query()->create([
            'tournament_id' => $tournamentId,
            'tournament_category_id' => $category->id,
            'phase' => 'single_elimination',
            'round_index' => 0,
            'match_index' => 0,
            'team_a_id' => $advancerIds[0],
            'team_b_id' => null,
            'status' => 'finished',
            'winner_team_id' => $advancerIds[0],
        ]);

        \App\Models\TournamentMatch::query()->create([
            'tournament_id' => $tournamentId,
            'tournament_category_id' => $category->id,
            'phase' => 'single_elimination',
            'round_index' => 0,
            'match_index' => 1,
            'team_a_id' => $advancerIds[1],
            'team_b_id' => $advancerIds[2],
            'status' => 'scheduled',
        ]);

        $category->update(['phase' => 'single_elimination']);

        $repaired = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('final_round_robin', $repaired['categories'][0]['phase']);
        $this->assertNull($repaired['categories'][0]['bracket']);
        $this->assertCount(
            3,
            collect($repaired['categories'][0]['matches'])->where('phase', 'final_round_robin')
        );
    }

    public function test_final_round_robin_matches_wait_for_manual_court_assignment(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Final RR Courts',
                'group_count' => 3,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['Mac', 'Ben', 'Josh', 'Ivy', 'Kai', 'Leo'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        foreach ($state['categories'][0]['matches'] as $match) {
            if ($match['phase'] === 'round_robin') {
                $this->scoreMatch($tournamentId, $match['id'], 11, 4);
            }
        }

        $after = $this->getJson("/api/tournaments/{$tournamentId}")->json();
        $this->assertEquals('final_round_robin', $after['categories'][0]['phase']);

        $finalMatches = collect($after['categories'][0]['matches'])
            ->where('phase', 'final_round_robin')
            ->values();
        $this->assertCount(3, $finalMatches);

        $assignedToCourt = $finalMatches->whereNotNull('courtNumber');
        $this->assertCount(0, $assignedToCourt);

        $assignedCourts = collect($after['display']['courts'])
            ->filter(fn (array $court) => $court['match'] !== null)
            ->values();
        $this->assertCount(0, $assignedCourts);
        $this->assertCount(3, collect($after['display']['upNext'])->where('phase', 'final_round_robin'));
    }

    public function test_tournament_registration_does_not_appear_on_players_list(): void
    {
        $tournamentId = $this->createTournamentWithCategory('mens_singles_open:intermediate');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('mens_singles_open:intermediate').'/teams',
                [
                    'player_names' => ['Tourney Only Player'],
                    'genders' => ['male'],
                ],
            )
            ->assertOk();

        $players = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson('/api/players')
            ->json('players');

        $names = collect($players)->pluck('name')->all();
        $this->assertNotContains('Tourney Only Player', $names);
    }

    public function test_can_register_late_team_during_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Late Registration',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk();

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode($categoryKey).'/teams',
                [
                    'player_names' => ['Late Player'],
                    'genders' => ['male'],
                ],
            )
            ->assertOk()
            ->json();

        $lateTeam = collect($state['categories'][0]['teams'])
            ->firstWhere('displayName', 'Late Player');

        $this->assertNotNull($lateTeam);
        $this->assertNotNull($lateTeam['groupKey']);

        $scheduledAgainstLate = collect($state['categories'][0]['matches'])
            ->filter(fn ($match) => in_array($lateTeam['id'], [
                $match['teamA']['id'] ?? null,
                $match['teamB']['id'] ?? null,
            ], true))
            ->where('status', 'scheduled');

        $this->assertGreaterThanOrEqual(1, $scheduledAgainstLate->count());
    }

    public function test_can_remove_team_during_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Withdraw Team',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'A3', 'B1', 'B2', 'B3'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $before = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk()
            ->json();

        $teamId = $before['categories'][0]['teams'][0]['id'];

        $after = $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/tournaments/{$tournamentId}/teams/{$teamId}")
            ->assertOk()
            ->json();

        $this->assertFalse(
            collect($after['categories'][0]['teams'])->pluck('id')->contains($teamId),
        );

        $pendingForRemoved = collect($after['categories'][0]['matches'])
            ->filter(fn ($match) => in_array($teamId, [
                $match['teamA']['id'] ?? null,
                $match['teamB']['id'] ?? null,
            ], true))
            ->whereIn('status', ['scheduled', 'on_court']);

        $this->assertCount(0, $pendingForRemoved);
    }

    public function test_can_update_tournament_player_name_during_round_robin(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Edit Name',
                'group_count' => 2,
                'court_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated();

        $tournamentId = $response->json('tournament.id');
        $categoryKey = 'mens_singles_open:intermediate';

        foreach (['A1', 'A2', 'B1', 'B2'] as $name) {
            $this->registerTeam($tournamentId, $categoryKey, [
                $this->createMalePlayer($name, 'intermediate'),
            ]);
        }

        $started = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/tournaments/{$tournamentId}/start")
            ->assertOk()
            ->json();

        $team = $started['categories'][0]['teams'][0];
        $playerId = $team['players'][0]['id'];

        $updated = $this->withHeader('X-Admin-Pin', self::PIN)
            ->patchJson("/api/tournaments/{$tournamentId}/players/{$playerId}", [
                'name' => 'Corrected Name',
            ])
            ->assertOk()
            ->json();

        $updatedTeam = collect($updated['categories'][0]['teams'])
            ->firstWhere('id', $team['id']);

        $this->assertStringContainsString('Corrected Name', $updatedTeam['displayName']);
    }

    public function test_removing_tournament_team_deletes_orphaned_tournament_only_players(): void
    {
        $tournamentId = $this->createTournamentWithCategory('mens_singles_open:intermediate');

        $state = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('mens_singles_open:intermediate').'/teams',
                [
                    'player_names' => ['Temporary Tourney Player'],
                    'genders' => ['male'],
                ],
            )
            ->assertOk()
            ->json();

        $teamId = $state['categories'][0]['teams'][0]['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/tournaments/{$tournamentId}/teams/{$teamId}")
            ->assertOk();

        $this->assertDatabaseMissing('club_players', [
            'display_name' => 'Temporary Tourney Player',
            'is_tournament_only' => true,
        ]);
    }

    public function test_draw_lots_pairs_mens_doubles_and_registers_teams(): void
    {
        $tournamentId = $this->createTournamentWithCategory('mens_doubles_open:intermediate');

        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('mens_doubles_open:intermediate').'/draw-lots',
                [
                    'player_names' => ['Alice', 'Bob', 'Carol', 'Dave'],
                ],
            )
            ->assertOk();

        $pairs = $response->json('pairs');
        $this->assertCount(2, $pairs);
        $this->assertCount(2, $response->json('state.categories.0.teams'));
    }

    public function test_draw_lots_mixed_doubles_requires_balanced_genders(): void
    {
        $tournamentId = $this->createTournamentWithCategory('mixed_doubles_open:intermediate');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('mixed_doubles_open:intermediate').'/draw-lots',
                [
                    'player_names' => ['Alex', 'Blair', 'Casey'],
                    'genders' => ['male', 'female', 'male'],
                ],
            )
            ->assertStatus(422);
    }

    public function test_draw_lots_skill_doubles_allows_genderless_pairing(): void
    {
        $tournamentId = $this->createTournamentWithCategory('skill_doubles_open:beginner');

        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('skill_doubles_open:beginner').'/draw-lots',
                [
                    'player_names' => ['Player A', 'Player B', 'Player C', 'Player D'],
                ],
            )
            ->assertOk();

        $this->assertCount(2, $response->json('pairs'));
        $this->assertCount(2, $response->json('state.categories.0.teams'));
    }

    public function test_active_tournament_endpoint_returns_ok_when_none_live(): void
    {
        $this->getJson('/api/tournaments/active')
            ->assertOk()
            ->assertJson([
                'active' => false,
                'message' => 'No live tournament',
            ]);
    }
}
