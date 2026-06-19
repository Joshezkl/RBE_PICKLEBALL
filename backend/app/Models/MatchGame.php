<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchGame extends Model
{
    protected $table = 'matches';

    protected $fillable = [
        'play_session_id',
        'court_id',
        'team_a_player1',
        'team_a_player2',
        'team_b_player1',
        'team_b_player2',
        'score_a',
        'score_b',
        'winner_team',
        'status',
        'is_challenge_court',
        'started_at',
        'finished_at',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'is_challenge_court' => 'boolean',
        ];
    }

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function court(): BelongsTo
    {
        return $this->belongsTo(Court::class);
    }

    public function teamAPlayer1(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'team_a_player1');
    }

    public function teamAPlayer2(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'team_a_player2');
    }

    public function teamBPlayer1(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'team_b_player1');
    }

    public function teamBPlayer2(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'team_b_player2');
    }
}
