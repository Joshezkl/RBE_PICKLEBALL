<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Player extends Model
{
    protected $fillable = [
        'play_session_id',
        'club_player_id',
        'name',
        'skill_level',
        'gender',
        'last_partner_id',
        'partner_phase',
        'wins',
        'losses',
        'is_active',
        'availability',
        'away_queue_type',
        'away_queue_position',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeInRotation(Builder $query): Builder
    {
        return $query->where('is_active', true)->where('availability', 'active');
    }

    public function isAway(): bool
    {
        return $this->availability === 'away';
    }

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function clubPlayer(): BelongsTo
    {
        return $this->belongsTo(ClubPlayer::class);
    }

    public function lastPartner(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'last_partner_id');
    }

    public function queueEntry(): HasOne
    {
        return $this->hasOne(QueueEntry::class);
    }
}
