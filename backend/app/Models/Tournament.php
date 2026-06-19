<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Tournament extends Model
{
    protected $fillable = [
        'name',
        'status',
        'registration_token',
        'advance_count',
        'group_count',
        'court_count',
        'settings',
        'started_at',
        'ended_at',
    ];

    protected function casts(): array
    {
        return [
            'settings' => 'array',
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
        ];
    }

    public function categories(): HasMany
    {
        return $this->hasMany(TournamentCategory::class);
    }

    public function teams(): HasMany
    {
        return $this->hasMany(TournamentTeam::class);
    }

    public function matches(): HasMany
    {
        return $this->hasMany(TournamentMatch::class);
    }
}
