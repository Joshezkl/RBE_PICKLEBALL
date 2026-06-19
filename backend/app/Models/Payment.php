<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    public const METHOD_CASH = 'cash';

    public const METHOD_TRANSFER = 'transfer';

    public const METHOD_OTHER = 'other';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_WAIVED = 'waived';

    protected $fillable = [
        'play_session_id',
        'club_player_id',
        'session_player_id',
        'amount_cents',
        'method',
        'status',
        'recorded_at',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'recorded_at' => 'datetime',
        ];
    }

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function clubPlayer(): BelongsTo
    {
        return $this->belongsTo(ClubPlayer::class);
    }

    public function sessionPlayer(): BelongsTo
    {
        return $this->belongsTo(SessionPlayer::class);
    }
}
