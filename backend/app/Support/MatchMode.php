<?php

namespace App\Support;

abstract class MatchMode
{
    public const AUTO_BALANCED = 'auto_balanced';

    public const SKILL_SEPARATED = 'skill_separated';

    public const WINNER_LOSER_GROUPS = 'winner_loser_groups';

    public const MIXED_DOUBLES = 'mixed_doubles';

    public const SKILL_COURTS = 'skill_courts';

    public const SINGLES = 'singles';

    public const KING_QUEEN_COURT = 'king_queen_court';

    public const ALL = [
        self::AUTO_BALANCED,
        self::SKILL_SEPARATED,
        self::WINNER_LOSER_GROUPS,
        self::MIXED_DOUBLES,
        self::SKILL_COURTS,
        self::SINGLES,
        self::KING_QUEEN_COURT,
    ];

    public const SKILL_LEVELS = ['beginner', 'novice', 'intermediate', 'advanced'];

    public const GENDERS = ['male', 'female'];

    public static function isValid(string $mode): bool
    {
        return in_array($mode, self::ALL, true);
    }

    public static function usesSkillQueues(string $mode): bool
    {
        return in_array($mode, [self::SKILL_SEPARATED, self::SKILL_COURTS], true);
    }

    public static function usesWinnerLoserQueues(string $mode): bool
    {
        return ! self::usesSkillQueues($mode);
    }

    public static function usesPartnerRotation(string $mode): bool
    {
        return in_array($mode, [self::AUTO_BALANCED, self::MIXED_DOUBLES], true);
    }

    public static function prefersMixedTeams(string $mode): bool
    {
        return $mode === self::MIXED_DOUBLES;
    }

    public static function forcesSingles(string $mode): bool
    {
        return $mode === self::SINGLES;
    }

    public static function requiresSkillLevel(string $mode): bool
    {
        return in_array($mode, [self::SKILL_SEPARATED, self::SKILL_COURTS], true);
    }

    public static function requiresGender(string $mode): bool
    {
        return $mode === self::MIXED_DOUBLES;
    }

    public static function queueLabel(string $queueType): string
    {
        return match ($queueType) {
            'winner' => 'Winners Queue',
            'loser' => 'Losers Queue',
            'beginner', 'novice', 'intermediate', 'advanced' => ucfirst($queueType),
            'male' => 'Male Queue',
            'female' => 'Female Queue',
            default => ucfirst(str_replace('_', ' ', $queueType)),
        };
    }

    public static function label(string $mode): string
    {
        return match ($mode) {
            self::AUTO_BALANCED => 'Auto-Balanced',
            self::SKILL_SEPARATED => 'Skill-Separated',
            self::WINNER_LOSER_GROUPS => 'Winner/Loser Groups',
            self::MIXED_DOUBLES => 'Mixed Doubles',
            self::SKILL_COURTS => 'Skill Courts',
            self::SINGLES => 'Singles',
            self::KING_QUEEN_COURT => 'King/Queen of the Court',
            default => $mode,
        };
    }
}
