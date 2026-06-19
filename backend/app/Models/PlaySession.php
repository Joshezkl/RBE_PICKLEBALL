<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PlaySession extends Model
{
    protected $fillable = [
        'name',
        'status',
        'check_in_token',
        'match_mode',
        'match_mode_settings',
        'play_format',
        'court_count',
        'auto_assign_enabled',
        'require_payment',
        'session_fee_cents',
        'next_court_queue',
        'next_new_player_queue',
        'new_players_joined_count',
        'started_at',
        'ended_at',
        'report_data',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'report_data' => 'array',
            'match_mode_settings' => 'array',
            'auto_assign_enabled' => 'boolean',
            'require_payment' => 'boolean',
            'session_fee_cents' => 'integer',
            'new_players_joined_count' => 'integer',
        ];
    }

    public function players(): HasMany
    {
        return $this->hasMany(Player::class);
    }

    public function courts(): HasMany
    {
        return $this->hasMany(Court::class);
    }

    public function queues(): HasMany
    {
        return $this->hasMany(QueueEntry::class);
    }

    public function matches(): HasMany
    {
        return $this->hasMany(MatchGame::class);
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    public function groupSize(): int
    {
        return $this->play_format === 'singles' ? 2 : 4;
    }
}
