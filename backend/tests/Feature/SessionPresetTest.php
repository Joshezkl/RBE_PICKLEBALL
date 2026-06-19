<?php

namespace Tests\Feature;

use App\Models\SessionPreset;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SessionPresetTest extends TestCase
{
    use RefreshDatabase;

    private const PIN = '1234';

    public function test_create_list_and_delete_preset(): void
    {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session-presets', [
                'name' => 'Friday Night',
                'match_mode' => 'auto_balanced',
                'play_format' => 'doubles',
                'court_count' => 4,
                'auto_assign_enabled' => true,
            ])
            ->assertCreated()
            ->assertJsonPath('name', 'Friday Night')
            ->assertJsonPath('autoAssignEnabled', true);

        $list = $this->withHeader('X-Admin-Pin', self::PIN)
            ->getJson('/api/session-presets')
            ->assertOk()
            ->json('presets');

        $this->assertCount(1, $list);
        $this->assertEquals('Friday Night', $list[0]['name']);

        $preset = SessionPreset::query()->firstOrFail();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->deleteJson("/api/session-presets/{$preset->id}")
            ->assertOk();

        $this->assertDatabaseCount('session_presets', 0);
    }

    public function test_start_session_from_preset_values(): void
    {
        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/session-presets', [
                'name' => 'Quick Doubles',
                'match_mode' => 'king_queen_court',
                'play_format' => 'doubles',
                'court_count' => 3,
                'auto_assign_enabled' => true,
            ])
            ->assertCreated();

        $preset = SessionPreset::query()->firstOrFail();

        $this->withHeader('X-Admin-Pin', self::PIN)
            ->postJson('/api/sessions', [
                'name' => $preset->name,
                'match_mode' => $preset->match_mode,
                'play_format' => $preset->play_format,
                'court_count' => $preset->court_count,
                'auto_assign_enabled' => $preset->auto_assign_enabled,
            ])
            ->assertCreated()
            ->assertJsonPath('session.matchMode', 'king_queen_court')
            ->assertJsonPath('session.courtCount', 3)
            ->assertJsonPath('session.autoAssignEnabled', true);
    }
}
