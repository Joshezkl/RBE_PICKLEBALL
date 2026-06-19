<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Court extends Model
{
    protected $fillable = [
        'play_session_id',
        'court_number',
        'skill_bracket',
        'is_challenge_court',
        'status',
        'current_match_id',
    ];

    protected function casts(): array
    {
        return [
            'is_challenge_court' => 'boolean',
        ];
    }

    public function playSession(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class);
    }

    public function currentMatch(): BelongsTo
    {
        return $this->belongsTo(MatchGame::class, 'current_match_id');
    }
}
