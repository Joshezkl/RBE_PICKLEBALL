<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QueueEntry extends Model
{
    protected $table = 'queues';

    protected $fillable = [
        'play_session_id',
        'player_id',
        'queue_type',
        'position',
    ];

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function player(): BelongsTo
    {
        return $this->belongsTo(Player::class);
    }
}
