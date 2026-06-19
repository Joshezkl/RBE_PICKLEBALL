<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SessionHistoryTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_calendar_and_history_endpoints(): void
    {
        $create = $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', ['name' => 'Morning Play']);

        $sessionId = $create->json('session.id');

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson("/api/sessions/{$sessionId}/end")
            ->assertOk();

        $year = (int) now()->format('Y');
        $month = (int) now()->format('n');
        $today = now()->format('Y-m-d');

        $calendar = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/sessions/calendar?year={$year}&month={$month}")
            ->assertOk()
            ->json();

        $this->assertArrayHasKey($today, $calendar['markers']);

        $byDate = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/sessions/history?date={$today}")
            ->assertOk()
            ->json();

        $this->assertNotEmpty($byDate['sessions']);
        $this->assertEquals('Morning Play', $byDate['sessions'][0]['name']);

        $detail = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson("/api/sessions/{$sessionId}/history")
            ->assertOk()
            ->assertJsonStructure([
                'session' => ['id', 'name', 'matchModeLabel'],
                'report' => ['totalMatches', 'playerSummaries'],
                'matches',
                'players',
            ])
            ->json();

        $this->assertEquals('Morning Play', $detail['session']['name']);
    }
}
