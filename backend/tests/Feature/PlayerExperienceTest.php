<?php

namespace Tests\Feature;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PlayerExperienceTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_guest_registration_does_not_affect_all_time_leaderboard(): void
    {
        $session = $this->createActiveSession();

        $this->postJson('/api/check-in/register', [
            'name' => 'Visitor',
            'skill_level' => 'beginner',
            'gender' => 'male',
            'is_guest' => true,
        ], [
            'X-Check-In-Token' => $session['token'],
        ])->assertCreated()
            ->assertJsonPath('player.isGuest', true);

        $this->getJson('/api/leaderboard/all-time')
            ->assertOk()
            ->assertJsonCount(0, 'leaderboard');
    }

    public function test_player_can_step_out_and_step_back(): void
    {
        $session = $this->createActiveSession();

        $register = $this->postJson('/api/check-in/register', [
            'name' => 'Stepper',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ], [
            'X-Check-In-Token' => $session['token'],
        ])->assertCreated();

        $clubPlayerId = $register->json('player.id');

        $this->postJson('/api/check-in/step-out', [
            'club_player_id' => $clubPlayerId,
        ], [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('status', 'away');

        $state = $this->getJson("/api/sessions/{$session['id']}/state")->assertOk();
        $queuedNames = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertFalse($queuedNames->contains('Stepper'));

        $this->postJson('/api/check-in/step-back', [
            'club_player_id' => $clubPlayerId,
        ], [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('status', 'waiting');

        $state = $this->getJson("/api/sessions/{$session['id']}/state")->assertOk();
        $queuedNames = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertTrue($queuedNames->contains('Stepper'));
    }

    public function test_queue_status_includes_position_details(): void
    {
        $session = $this->createActiveSession();

        foreach (['A', 'B', 'C', 'D'] as $name) {
            $this->postJson('/api/check-in/register', [
                'name' => $name,
                'skill_level' => 'beginner',
                'gender' => 'male',
            ], [
                'X-Check-In-Token' => $session['token'],
            ])->assertCreated();
        }

        $clubPlayer = ClubPlayer::query()->where('display_name', 'D')->orWhere('name', 'D')->first();
        $this->assertNotNull($clubPlayer);

        $this->getJson('/api/check-in/status?club_player_id='.$clubPlayer->id, [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('inSession', true)
            ->assertJsonStructure([
                'status',
                'message',
                'position',
                'playersAhead',
                'groupsAhead',
                'playerName',
            ]);
    }

    public function test_playing_status_detects_court_assignment(): void
    {
        $session = $this->createActiveSession();

        foreach (['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session['id']}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session['id']}/state")->json();
        $courtId = $this->regularCourtId($state);
        $playerIds = collect($state['queues']['winner'])->merge($state['queues']['loser'])->pluck('id')->take(4)->values()->all();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session['id']}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $after = $this->getJson("/api/sessions/{$session['id']}/state")->json();
        $court = collect($after['courts'])->firstWhere('id', $courtId);
        $onCourt = \App\Models\Player::query()
            ->findOrFail($court['match']['teamA']['player1']['id'])
            ->clubPlayer;
        $this->assertNotNull($onCourt);

        $this->getJson('/api/check-in/status?club_player_id='.$onCourt->id, [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('status', 'playing')
            ->assertJsonPath('courtNumber', $court['courtNumber']);
    }

    private function createActiveSession(): array
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'Player UX Session',
                'court_count' => 2,
            ])
            ->assertCreated();

        return [
            'id' => $response->json('session.id'),
            'token' => $response->json('session.checkInToken'),
        ];
    }
}
