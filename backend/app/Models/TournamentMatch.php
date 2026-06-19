<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TournamentMatch extends Model
{
    protected $fillable = [
        'tournament_id',
        'tournament_category_id',
        'group_key',
        'phase',
        'round_index',
        'match_index',
        'team_a_id',
        'team_b_id',
        'score_a',
        'score_b',
        'winner_team_id',
        'feeds_into_match_id',
        'feed_slot',
        'status',
        'court_number',
    ];

    public function tournament(): BelongsTo
    {
        return $this->belongsTo(Tournament::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(TournamentCategory::class, 'tournament_category_id');
    }

    public function teamA(): BelongsTo
    {
        return $this->belongsTo(TournamentTeam::class, 'team_a_id');
    }

    public function teamB(): BelongsTo
    {
        return $this->belongsTo(TournamentTeam::class, 'team_b_id');
    }

    public function winnerTeam(): BelongsTo
    {
        return $this->belongsTo(TournamentTeam::class, 'winner_team_id');
    }

    public function feedsIntoMatch(): BelongsTo
    {
        return $this->belongsTo(TournamentMatch::class, 'feeds_into_match_id');
    }
}
