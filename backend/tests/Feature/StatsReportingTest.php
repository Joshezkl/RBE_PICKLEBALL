<?php

namespace Tests\Feature;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StatsReportingTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_match_scoring_records_point_differential(): void
    {
        $session = $this->startSessionAndAssignMatch();

        $winner = ClubPlayer::query()
            ->where('total_wins', '>=', 1)
            ->orderByDesc('total_points_scored')
            ->firstOrFail();

        $this->assertGreaterThan(0, $winner->total_points_scored);
        $this->assertGreaterThan(0, $winner->total_points_allowed);
        $this->assertSame(7, $winner->pointDifferential());
        $this->assertSame(7.0, $winner->avgMargin());
    }

    public function test_monthly_and_season_leaderboards(): void
    {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', ['court_count' => 1])
            ->assertCreated();

        $this->getJson('/api/leaderboard/monthly')
            ->assertOk()
            ->assertJsonStructure(['scope', 'year', 'month', 'label', 'leaderboard']);

        $this->getJson('/api/leaderboard/season?year=2026')
            ->assertOk()
            ->assertJsonPath('scope', 'season')
            ->assertJsonPath('year', 2026);
    }

    public function test_player_profile_and_session_export(): void
    {
        $session = $this->startSessionAndAssignMatch();
        $clubPlayer = ClubPlayer::query()->firstOrFail();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/players/{$clubPlayer->id}")
            ->assertOk()
            ->assertJsonStructure([
                'name',
                'pointDifferential',
                'sessionHistory',
                'bestPartners',
                'preferredMode',
                'winRateTrend',
            ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->get("/api/sessions/{$session->id}/export")
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8')
            ->assertSee('Revenue Summary', escape: false);
    }

    public function test_session_export_includes_revenue_when_payments_recorded(): void
    {
        $session = $this->createPaidSession();
        $clubPlayer = ClubPlayer::query()->create([
            'name' => 'Export Payer',
            'skill_level' => 'beginner',
            'gender' => 'male',
        ]);

        \App\Models\SessionPlayer::query()->create([
            'play_session_id' => $session->id,
            'club_player_id' => $clubPlayer->id,
            'payment_status' => \App\Support\PaymentStatus::PENDING,
        ]);

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/registrations/{$clubPlayer->id}/mark-paid")
            ->assertOk();

        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->get("/api/sessions/{$session->id}/export")
            ->assertOk();

        $this->assertStringContainsString('Revenue Summary', $response->getContent());
        $this->assertStringContainsString('Payment Transactions', $response->getContent());
        $this->assertStringContainsString('Export Payer', $response->getContent());
        $this->assertStringContainsString('50.00', $response->getContent());
    }

    private function createPaidSession(): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'court_count' => 1,
                'require_payment' => true,
                'session_fee_cents' => 5000,
            ])
            ->assertCreated();

        return PlaySession::query()->findOrFail($response->json('session.id'));
    }

    private function startSessionAndAssignMatch(): PlaySession
    {
        $response = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', ['court_count' => 2])
            ->assertCreated();

        $session = PlaySession::query()->findOrFail($response->json('session.id'));

        foreach (['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'C3', 'C4'] as $name) {
            $this->withHeader('X-Admin-Pin', self::PIN)
                ->postJson("/api/sessions/{$session->id}/players", ['name' => $name]);
        }

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $courtId = $this->regularCourtId($state);
        $playerIds = collect($state['queues']['winner'])->merge($state['queues']['loser'])->pluck('id')->take(4)->values()->all();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/courts/{$courtId}/assign", [
                'player_ids' => $playerIds,
            ])
            ->assertOk();

        $state = $this->getJson("/api/sessions/{$session->id}/state")->json();
        $matchId = collect($state['courts'])->firstWhere('id', $courtId)['match']['id'];

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$session->id}/matches/{$matchId}/score", [
                'score_a' => 11,
                'score_b' => 4,
            ])
            ->assertOk();

        return $session->fresh();
    }
}
