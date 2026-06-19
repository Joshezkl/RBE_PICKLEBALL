<?php

namespace App\Support;

abstract class TournamentSkillLevel
{
    public const BEGINNER = 'beginner';

    public const NOVICE = 'novice';

    public const INTERMEDIATE = 'intermediate';

    public const ADVANCED = 'advanced';

    public const ALL = [
        self::BEGINNER,
        self::NOVICE,
        self::INTERMEDIATE,
        self::ADVANCED,
    ];

    public static function label(string $level): string
    {
        return match ($level) {
            self::BEGINNER => 'Beginner',
            self::NOVICE => 'Novice',
            self::INTERMEDIATE => 'Intermediate',
            self::ADVANCED => 'Advanced',
            default => ucfirst($level),
        };
    }

    public static function isValid(string $level): bool
    {
        return in_array($level, self::ALL, true);
    }
}
