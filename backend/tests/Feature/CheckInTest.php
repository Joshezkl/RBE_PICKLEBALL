<?php

namespace Tests\Feature;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CheckInTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    private function createActiveSession(): array
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => 'QR Session',
                'court_count' => 2,
                'play_format' => 'doubles',
            ])
            ->assertCreated();

        return [
            'id' => $response->json('session.id'),
            'token' => $response->json('session.checkInToken'),
        ];
    }

    public function test_active_session_includes_check_in_token(): void
    {
        $session = $this->createActiveSession();

        $this->assertNotEmpty($session['token']);

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $this->assertEquals($session['token'], $state->json('session.checkInToken'));
    }

    public function test_check_in_session_info_requires_valid_token(): void
    {
        $session = $this->createActiveSession();

        $this->getJson('/api/check-in/session', [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('sessionName', 'QR Session');

        $this->getJson('/api/check-in/session', [
            'X-Check-In-Token' => 'invalid-token',
        ])->assertNotFound();
    }

    public function test_player_can_register_and_join_via_check_in(): void
    {
        $session = $this->createActiveSession();

        $response = $this->postJson('/api/check-in/register', [
            'name' => 'QR Player',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ], [
            'X-Check-In-Token' => $session['token'],
        ])->assertCreated();

        $clubPlayerId = $response->json('player.id');
        $this->assertTrue($response->json('joined'));
        $this->assertEquals('waiting', $response->json('status.status'));

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $names = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertTrue($names->contains('QR Player'));

        $this->postJson('/api/check-in/join', [
            'club_player_id' => $clubPlayerId,
        ], [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertOk()
            ->assertJsonPath('message', 'You are already checked in');
    }

    public function test_existing_club_player_can_join_via_check_in(): void
    {
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Existing',
            'skill_level' => 'intermediate',
            'gender' => 'female',
        ]);

        $session = $this->createActiveSession();

        $this->postJson('/api/check-in/join', [
            'club_player_id' => $clubPlayer->id,
        ], [
            'X-Check-In-Token' => $session['token'],
        ])
            ->assertCreated()
            ->assertJsonPath('status.inSession', true);
    }

    public function test_check_in_fails_when_session_ended(): void
    {
        $session = $this->createActiveSession();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session['id']}/end")
            ->assertOk();

        $this->getJson('/api/check-in/session', [
            'X-Check-In-Token' => $session['token'],
        ])->assertNotFound();
    }
}
