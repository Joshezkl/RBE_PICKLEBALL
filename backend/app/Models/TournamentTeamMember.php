<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TournamentTeamMember extends Model
{
    protected $fillable = [
        'tournament_team_id',
        'club_player_id',
    ];

    public function team(): BelongsTo
    {
        return $this->belongsTo(TournamentTeam::class, 'tournament_team_id');
    }

    public function clubPlayer(): BelongsTo
    {
        return $this->belongsTo(ClubPlayer::class);
    }
}
