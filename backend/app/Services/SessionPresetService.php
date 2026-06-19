<?php

namespace App\Services;

use App\Models\SessionPreset;
use App\Support\MatchMode;

class SessionPresetService
{
    /**
     * @return list<array<string, mixed>>
     */
    public function list(): array
    {
        return SessionPreset::query()
            ->orderBy('name')
            ->get()
            ->map(fn (SessionPreset $preset) => $this->format($preset))
            ->values()
            ->all();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(array $data): SessionPreset
    {
        return SessionPreset::query()->create($this->normalize($data));
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(SessionPreset $preset, array $data): SessionPreset
    {
        $preset->update($this->normalize($data));

        return $preset->fresh();
    }

    public function delete(SessionPreset $preset): void
    {
        $preset->delete();
    }

    /**
     * @return array<string, mixed>
     */
    public function format(SessionPreset $preset): array
    {
        return [
            'id' => $preset->id,
            'name' => $preset->name,
            'matchMode' => $preset->match_mode,
            'matchModeLabel' => MatchMode::label($preset->match_mode),
            'playFormat' => $preset->play_format,
            'courtCount' => $preset->court_count,
            'autoAssignEnabled' => $preset->auto_assign_enabled,
            'matchModeSettings' => $preset->match_mode_settings,
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function normalize(array $data): array
    {
        return [
            'name' => $data['name'],
            'match_mode' => $data['match_mode'],
            'play_format' => $data['play_format'] ?? 'doubles',
            'court_count' => $data['court_count'] ?? 4,
            'auto_assign_enabled' => (bool) ($data['auto_assign_enabled'] ?? false),
            'match_mode_settings' => $data['match_mode_settings'] ?? null,
        ];
    }
}
