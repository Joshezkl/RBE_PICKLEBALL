<?php

namespace Tests\Feature;

use App\Models\PlaySession;
use App\Models\Player;
use App\Models\SessionPartnerPair;
use App\Services\MatchModeService;
use App\Services\PairingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PairingServiceTest extends TestCase
{
    use RefreshDatabase;

    private PairingService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new PairingService(new MatchModeService);
    }

    public function test_never_pairs_previous_partners_on_same_team(): void
    {
        $session = $this->makeDoublesSession();
        $players = $this->makeSessionPlayers($session, 4);

        SessionPartnerPair::record($session->id, $players[0]->id, $players[1]->id);

        $teams = $this->service->formTeams(collect($players), $session);

        $this->assertPartnersNotTogether($teams, $players[0]->id, $players[1]->id);
    }

    public function test_allows_previous_partners_on_opposite_teams(): void
    {
        $session = $this->makeDoublesSession();
        $players = $this->makeSessionPlayers($session, 4);

        SessionPartnerPair::record($session->id, $players[0]->id, $players[1]->id);
        SessionPartnerPair::record($session->id, $players[2]->id, $players[3]->id);

        $teams = $this->service->formTeams(collect($players), $session);

        $this->assertPartnersOnOppositeTeams($teams, $players[0]->id, $players[1]->id);
    }

    public function test_second_match_avoids_repeating_partners_after_assignment(): void
    {
        $session = $this->makeDoublesSession();
        $players = $this->makeSessionPlayers($session, 4);

        $firstTeams = $this->service->formTeams(collect($players), $session);
        $this->service->updatePartnerState($session, $firstTeams['teamA'], $firstTeams['teamB']);

        $secondTeams = $this->service->formTeams(collect($players), $session->fresh());

        foreach ([$firstTeams['teamA'], $firstTeams['teamB']] as $team) {
            if (count($team) === 2) {
                $this->assertPartnersNotTogether($secondTeams, $team[0]->id, $team[1]->id);
            }
        }
    }

    public function test_update_player_name_in_active_session(): void
    {
        $session = $this->makeDoublesSession();
        $players = $this->makeSessionPlayers($session, 1, ['Typo Name']);

        $this->withHeader('X-Admin-Pin', '1234')
            ->patchJson("/api/sessions/{$session->id}/players/{$players[0]->id}", [
                'name' => 'Correct Name',
            ])
            ->assertOk()
            ->assertJsonPath('player.name', 'Correct Name');

        $this->assertDatabaseHas('players', [
            'id' => $players[0]->id,
            'name' => 'Correct Name',
        ]);
    }

    public function test_update_player_name_rejects_duplicate_session_names(): void
    {
        $session = $this->makeDoublesSession();
        $players = $this->makeSessionPlayers($session, 2, ['Alice', 'Bob']);

        $this->withHeader('X-Admin-Pin', '1234')
            ->patchJson("/api/sessions/{$session->id}/players/{$players[1]->id}", [
                'name' => 'Alice',
            ])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Player name already exists in this session');
    }

    private function makeDoublesSession(): PlaySession
    {
        return PlaySession::query()->create([
            'name' => 'Pairing Test',
            'status' => 'active',
            'match_mode' => 'auto_balanced',
            'play_format' => 'doubles',
            'court_count' => 1,
            'started_at' => now(),
        ]);
    }

    /**
     * @param  array<int, string>  $names
     * @return array<int, Player>
     */
    private function makeSessionPlayers(PlaySession $session, int $count, array $names = []): array
    {
        $players = [];
        for ($i = 0; $i < $count; $i++) {
            $players[] = Player::query()->create([
                'play_session_id' => $session->id,
                'name' => $names[$i] ?? 'Player '.($i + 1),
                'is_active' => true,
            ]);
        }

        return $players;
    }

    /**
     * @param  array{teamA: array<int, Player>, teamB: array<int, Player>}  $teams
     */
    private function assertPartnersNotTogether(array $teams, int $playerAId, int $playerBId): void
    {
        $teamAIds = collect($teams['teamA'])->pluck('id')->sort()->values()->all();
        $teamBIds = collect($teams['teamB'])->pluck('id')->sort()->values()->all();
        $pair = collect([$playerAId, $playerBId])->sort()->values()->all();

        $this->assertNotEquals($pair, $teamAIds);
        $this->assertNotEquals($pair, $teamBIds);
    }

    /**
     * @param  array{teamA: array<int, Player>, teamB: array<int, Player>}  $teams
     */
    private function assertPartnersOnOppositeTeams(array $teams, int $playerAId, int $playerBId): void
    {
        $teamAIds = collect($teams['teamA'])->pluck('id')->all();
        $teamBIds = collect($teams['teamB'])->pluck('id')->all();

        $this->assertTrue(
            (in_array($playerAId, $teamAIds) && in_array($playerBId, $teamBIds))
            || (in_array($playerBId, $teamAIds) && in_array($playerAId, $teamBIds))
        );
    }
}
