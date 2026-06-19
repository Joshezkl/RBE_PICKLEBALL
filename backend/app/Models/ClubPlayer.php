<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ClubPlayer extends Model
{
    protected $fillable = [
        'name',
        'display_name',
        'skill_level',
        'gender',
        'is_guest',
        'is_tournament_only',
        'total_matches',
        'total_wins',
        'total_losses',
        'total_points_scored',
        'total_points_allowed',
    ];

    public function pointDifferential(): int
    {
        return (int) $this->total_points_scored - (int) $this->total_points_allowed;
    }

    public function avgMargin(): float
    {
        $matches = (int) ($this->total_matches ?? 0);
        if ($matches <= 0) {
            return 0.0;
        }

        return round($this->pointDifferential() / $matches, 1);
    }

    protected function casts(): array
    {
        return [
            'is_guest' => 'boolean',
            'is_tournament_only' => 'boolean',
        ];
    }

    public function publicName(): string
    {
        return $this->display_name ?? $this->name;
    }

    public function sessionPlayers(): HasMany
    {
        return $this->hasMany(SessionPlayer::class);
    }

    public function rosterEntries(): HasMany
    {
        return $this->hasMany(Player::class);
    }

    public function winRate(): float
    {
        $matches = (int) ($this->total_matches ?? 0);
        if ($matches <= 0) {
            return 0.0;
        }

        return round(((int) $this->total_wins / $matches) * 100, 1);
    }
}
