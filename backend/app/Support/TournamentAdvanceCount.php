<?php

namespace App\Support;

abstract class TournamentAdvanceCount
{
    public const ALL = [1, 2, 4, 8];

    public static function isValid(int $count): bool
    {
        return in_array($count, self::ALL, true);
    }

    public static function label(int $count): string
    {
        return match ($count) {
            1 => 'Top 1 (champion after round robin)',
            2 => 'Top 2 (final)',
            4 => 'Top 4 (semifinals + final)',
            8 => 'Top 8 (quarterfinals + semifinals + final)',
            default => "Top {$count}",
        };
    }
}
