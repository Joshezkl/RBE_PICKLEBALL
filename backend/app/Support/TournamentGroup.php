<?php

namespace App\Support;

abstract class TournamentGroup
{
    public const MAX_GROUPS = 12;

    public const KEYS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];

    /**
     * @return list<string>
     */
    public static function keysForCount(int $count): array
    {
        if ($count < 1 || $count > self::MAX_GROUPS) {
            throw new \InvalidArgumentException('Group count must be between 1 and '.self::MAX_GROUPS);
        }

        return array_slice(self::KEYS, 0, $count);
    }

    public static function label(string $key): string
    {
        return 'Group '.$key;
    }

    public static function isValidKey(string $key, int $groupCount): bool
    {
        return in_array($key, self::keysForCount($groupCount), true);
    }
}
