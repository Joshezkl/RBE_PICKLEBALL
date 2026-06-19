<?php

namespace Tests\Feature;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PlayerManagementTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_register_player_allows_duplicate_display_names(): void
    {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/players', [
                'name' => 'Alice',
                'skill_level' => 'intermediate',
                'gender' => 'female',
            ])
            ->assertCreated()
            ->assertJsonPath('player.name', 'Alice')
            ->assertJsonPath('player.skillLevel', 'intermediate')
            ->assertJsonPath('player.gender', 'female');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/players', [
                'name' => 'Alice',
                'skill_level' => 'beginner',
                'gender' => 'male',
            ])
            ->assertCreated()
            ->assertJsonPath('player.name', 'Alice')
            ->assertJsonPath('player.skillLevel', 'beginner')
            ->assertJsonPath('player.gender', 'male');

        $this->assertEquals(2, ClubPlayer::query()->where('display_name', 'Alice')->count());
    }

    public function test_match_scoring_updates_all_time_and_session_stats(): void
    {
        $session = $this->startSessionAndJoinFourPlayers();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);
        $playerIds = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->pluck('id')
            ->take(4)
            ->values()
            ->all();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);
        $matchId = collect($state['courts'])->firstWhere('id', $courtId)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 5,
            ])
            ->assertOk();

        $players = ClubPlayer::query()->orderBy('name')->get();
        $this->assertCount(4, $players);
        $this->assertEquals(4, $players->sum('total_matches'));
        $this->assertEquals(2, $players->sum('total_wins'));
        $this->assertEquals(2, $players->sum('total_losses'));
    }

    public function test_leaderboard_ranks_by_win_rate_then_wins_with_min_three_matches(): void
    {
        ClubPlayer::query()->create([
            'name' => 'HighRate',
            'total_matches' => 4,
            'total_wins' => 3,
            'total_losses' => 1,
        ]);
        ClubPlayer::query()->create([
            'name' => 'MoreWins',
            'total_matches' => 10,
            'total_wins' => 7,
            'total_losses' => 3,
        ]);
        ClubPlayer::query()->create([
            'name' => 'TooFew',
            'total_matches' => 2,
            'total_wins' => 2,
            'total_losses' => 0,
        ]);

        $response = $this->getJson('/api/leaderboard/all-time')->assertOk();
        $names = collect($response->json('leaderboard'))->pluck('name')->all();

        $this->assertEquals(['HighRate', 'MoreWins'], $names);
        $this->assertEquals(1, $response->json('leaderboard.0.rank'));
        $this->assertEquals(75.0, $response->json('leaderboard.0.winRate'));
    }

    public function test_join_skill_separated_session_routes_to_skill_queue(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Skill Session',
                'match_mode' => 'skill_separated',
                'court_count' => 2,
                'play_format' => 'doubles',
            ])
            ->assertCreated();

        $sessionId = $response->json('session.id');
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'SkillTester',
            'skill_level' => 'beginner',
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session/join', [
                'club_player_id' => $clubPlayer->id,
            ])
            ->assertCreated();

        $state = $this->getJson("/api/sessions/{$sessionId}/state")->json();

        $this->assertCount(1, $state['queues']['beginner']);
        $this->assertEquals('SkillTester', $state['queues']['beginner'][0]['name']);
    }

    public function test_join_skill_separated_session_uses_registered_intermediate_queue(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Skill Session',
                'match_mode' => 'skill_separated',
                'court_count' => 2,
                'play_format' => 'doubles',
            ])
            ->assertCreated();

        $sessionId = $response->json('session.id');
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'MidPlayer',
            'skill_level' => 'intermediate',
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session/join', ['club_player_id' => $clubPlayer->id])
            ->assertCreated();

        $state = $this->getJson("/api/sessions/{$sessionId}/state")->json();

        $this->assertCount(1, $state['queues']['intermediate']);
        $this->assertEquals('MidPlayer', $state['queues']['intermediate'][0]['name']);
    }

    public function test_join_mixed_doubles_session_uses_registered_gender(): void
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Mixed Session',
                'match_mode' => 'mixed_doubles',
                'court_count' => 1,
                'play_format' => 'doubles',
            ])
            ->assertCreated();

        $sessionId = $response->json('session.id');
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'MixedPlayer',
            'skill_level' => 'intermediate',
            'gender' => 'female',
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session/join', ['club_player_id' => $clubPlayer->id])
            ->assertCreated();

        $this->assertDatabaseHas('players', [
            'play_session_id' => $sessionId,
            'club_player_id' => $clubPlayer->id,
            'gender' => 'female',
        ]);
    }

    public function test_remove_player_with_match_history_deactivates_instead_of_delete(): void
    {
        $session = $this->startSessionAndJoinFourPlayers();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);
        $playerIds = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->pluck('id')
            ->take(4)
            ->values()
            ->all();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);
        $matchId = collect($state['courts'])->firstWhere('id', $courtId)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 7,
            ])
            ->assertOk();

        $alice = ClubPlayer::query()->where('name', 'Alice')->firstOrFail();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session/remove', ['club_player_id' => $alice->id])
            ->assertOk();

        $this->assertDatabaseHas('players', [
            'club_player_id' => $alice->id,
            'is_active' => false,
        ]);

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $queuedNames = collect($state['queues']['winner'])
            ->merge($state['queues']['loser'])
            ->pluck('name');

        $this->assertFalse($queuedNames->contains('Alice'));
    }

    public function test_delete_player_permanently(): void
    {
        $clubPlayer = ClubPlayer::query()->create(['name' => 'DeleteMe']);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/players/{$clubPlayer->id}")
            ->assertOk();

        $this->assertDatabaseMissing('club_players', ['id' => $clubPlayer->id]);
    }

    public function test_can_delete_club_player_linked_to_tournament(): void
    {
        $tournamentId = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/tournaments', [
                'name' => 'Delete Link Test',
                'group_count' => 2,
                'categories' => ['mens_singles_open:intermediate'],
            ])
            ->assertCreated()
            ->json('tournament.id');

        $playerId = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/players', [
                'name' => 'Linked Player',
                'skill_level' => 'intermediate',
                'gender' => 'male',
            ])
            ->json('player.id');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson(
                "/api/tournaments/{$tournamentId}/categories/".urlencode('mens_singles_open:intermediate').'/teams',
                ['player_ids' => [$playerId]],
            )
            ->assertOk();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/players/{$playerId}")
            ->assertOk();

        $this->assertDatabaseMissing('club_players', ['id' => $playerId]);
        $this->assertDatabaseMissing('tournament_team_members', [
            'club_player_id' => $playerId,
        ]);
    }

    private function startSessionAndJoinFourPlayers(): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Stats Session',
                'court_count' => 2,
                'play_format' => 'doubles',
            ])
            ->assertCreated();

        $session = PlaySession::query()->findOrFail($response->json('session.id'));

        foreach (['Alice', 'Bob', 'Carol', 'Dave'] as $name) {
            $clubPlayer = ClubPlayer::query()->create(['name' => $name]);
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson('/api/session/join', ['club_player_id' => $clubPlayer->id])
                ->assertCreated();
        }

        return $session;
    }
}
