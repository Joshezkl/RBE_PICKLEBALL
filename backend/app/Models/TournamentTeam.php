<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TournamentTeam extends Model
{
    protected $fillable = [
        'tournament_id',
        'tournament_category_id',
        'group_key',
        'display_name',
        'seed',
        'status',
        'wins',
        'losses',
        'points_scored',
        'points_allowed',
    ];

    public function tournament(): BelongsTo
    {
        return $this->belongsTo(Tournament::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(TournamentCategory::class, 'tournament_category_id');
    }

    public function members(): HasMany
    {
        return $this->hasMany(TournamentTeamMember::class);
    }

    public function pointDifferential(): int
    {
        return (int) $this->points_scored - (int) $this->points_allowed;
    }
}
