<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SessionPlayer extends Model
{
    protected $fillable = [
        'play_session_id',
        'club_player_id',
        'session_matches',
        'session_wins',
        'session_losses',
        'session_points_scored',
        'session_points_allowed',
        'payment_status',
        'payment_amount_cents',
        'payment_method',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'paid_at' => 'datetime',
        ];
    }

    public function canJoinQueue(): bool
    {
        return \App\Support\PaymentStatus::canJoinQueue($this->payment_status ?? 'free');
    }

    public function sessionPointDifferential(): int
    {
        return (int) $this->session_points_scored - (int) $this->session_points_allowed;
    }

    public function sessionAvgMargin(): float
    {
        $matches = (int) ($this->session_matches ?? 0);
        if ($matches <= 0) {
            return 0.0;
        }

        return round($this->sessionPointDifferential() / $matches, 1);
    }

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function clubPlayer(): BelongsTo
    {
        return $this->belongsTo(ClubPlayer::class);
    }

    public function sessionWinRate(): float
    {
        $matches = (int) ($this->session_matches ?? 0);
        if ($matches <= 0) {
            return 0.0;
        }

        return round(((int) $this->session_wins / $matches) * 100, 1);
    }
}
