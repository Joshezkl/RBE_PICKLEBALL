<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ChallengeCourtTeam extends Model
{
    public const STATUS_QUEUED = 'queued';

    public const STATUS_PLAYING = 'playing';

    public const STATUS_IDLE = 'idle';

    protected $fillable = [
        'play_session_id',
        'player1_id',
        'player2_id',
        'position',
        'status',
        'cc_wins',
        'court_id',
        'current_match_id',
    ];

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function player1(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'player1_id');
    }

    public function player2(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'player2_id');
    }

    public function currentMatch(): BelongsTo
    {
        return $this->belongsTo(MatchGame::class, 'current_match_id');
    }

    public function court(): BelongsTo
    {
        return $this->belongsTo(Court::class);
    }

    /**
     * @return list<int>
     */
    public function playerIds(): array
    {
        $ids = [$this->player1_id];
        if ($this->player2_id) {
            $ids[] = $this->player2_id;
        }

        return $ids;
    }
}
