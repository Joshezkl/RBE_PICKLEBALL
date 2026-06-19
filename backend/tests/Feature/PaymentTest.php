<?php

namespace Tests\Feature;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\SessionPlayer;
use App\Support\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PaymentTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    private function createPaidSession(array $overrides = []): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', array_merge([
                'name' => 'Paid Session',
                'court_count' => 2,
                'play_format' => 'doubles',
                'require_payment' => true,
                'session_fee_cents' => 5000,
            ], $overrides))
            ->assertCreated();

        return PlaySession::query()->findOrFail($response->json('session.id'));
    }

    public function test_free_session_joins_queue_immediately(): void
    {
        $session = $this->createPaidSession(['require_payment' => false]);
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Free Player',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ]);

        $this->postJson('/api/check-in/join', [
            'club_player_id' => $clubPlayer->id,
        ], [
            'X-Check-In-Token' => $session->check_in_token,
        ])->assertCreated();

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $names = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertTrue($names->contains('Free Player'));
    }

    public function test_paid_session_requires_payment_before_queue(): void
    {
        $session = $this->createPaidSession();
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Pending Player',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ]);

        $this->postJson('/api/check-in/join', [
            'club_player_id' => $clubPlayer->id,
        ], [
            'X-Check-In-Token' => $session->check_in_token,
        ])
            ->assertStatus(402)
            ->assertJsonPath('status.status', 'awaiting_payment');

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $this->assertCount(1, $state->json('pendingPayments'));
        $names = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertFalse($names->contains('Pending Player'));
    }

    public function test_mark_paid_activates_player_and_records_revenue(): void
    {
        $session = $this->createPaidSession();
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Paying Player',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ]);

        SessionPlayer::query()->create([
            'play_session_id' => $session->id,
            'club_player_id' => $clubPlayer->id,
            'payment_status' => PaymentStatus::PENDING,
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/registrations/{$clubPlayer->id}/mark-paid", [
                'method' => 'cash',
            ])
            ->assertOk()
            ->assertJsonPath('player.name', 'Paying Player');

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $names = collect($state->json('queues'))->flatten(1)->pluck('name');
        $this->assertTrue($names->contains('Paying Player'));
        $this->assertCount(0, $state->json('pendingPayments'));

        $revenue = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson('/api/admin/revenue')
            ->assertOk();

        $this->assertEquals(5000, $revenue->json('totalRevenueCents'));
        $this->assertEquals(1, $revenue->json('completedCount'));
    }

    public function test_step_out_and_back_does_not_require_repayment(): void
    {
        $session = $this->createPaidSession();
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Returner',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session/join', [
                'club_player_id' => $clubPlayer->id,
                'payment_action' => 'paid',
            ])
            ->assertCreated();

        $player = Player::query()->where('club_player_id', $clubPlayer->id)->firstOrFail();

        $this->postJson('/api/check-in/step-out', [
            'player_id' => $player->id,
        ], [
            'X-Check-In-Token' => $session->check_in_token,
        ])->assertOk();

        $this->postJson('/api/check-in/step-back', [
            'player_id' => $player->id,
        ], [
            'X-Check-In-Token' => $session->check_in_token,
        ])->assertOk();

        $sessionPlayer = SessionPlayer::query()
            ->where('club_player_id', $clubPlayer->id)
            ->firstOrFail();

        $this->assertEquals(PaymentStatus::PAID, $sessionPlayer->payment_status);
    }

    public function test_admin_can_add_player_as_pending(): void
    {
        $session = $this->createPaidSession();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/players", [
                'name' => 'Desk Pending',
                'payment_action' => 'pending',
            ])
            ->assertStatus(202)
            ->assertJsonPath('pending', true);

        $state = $this->getJson('/api/sessions/active')->assertOk();
        $this->assertCount(1, $state->json('pendingPayments'));
    }
}
