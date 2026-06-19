<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SessionPreset extends Model
{
    protected $fillable = [
        'name',
        'match_mode',
        'play_format',
        'court_count',
        'auto_assign_enabled',
        'match_mode_settings',
    ];

    protected function casts(): array
    {
        return [
            'auto_assign_enabled' => 'boolean',
            'match_mode_settings' => 'array',
        ];
    }
}
