<?php

namespace App\Support;

abstract class TournamentCategory
{
    public const KEY_SEPARATOR = ':';

    public const DIVISION_OPEN = 'open';

    public const DIVISION_35_PLUS = '35_plus';

    public const DIVISION_40_PLUS = '40_plus';

    public const DIVISION_50_PLUS = '50_plus';

    public const DIVISIONS = [
        self::DIVISION_OPEN,
        self::DIVISION_35_PLUS,
        self::DIVISION_40_PLUS,
        self::DIVISION_50_PLUS,
    ];

    /**
     * @return array<string, array{label: string, min_age: int|null}>
     */
    public static function divisionDefinitions(): array
    {
        return [
            self::DIVISION_OPEN => ['label' => 'Open Division', 'min_age' => null],
            self::DIVISION_35_PLUS => ['label' => '35+ Division', 'min_age' => 35],
            self::DIVISION_40_PLUS => ['label' => '40+ Division', 'min_age' => 40],
            self::DIVISION_50_PLUS => ['label' => '50+ Division', 'min_age' => 50],
        ];
    }

    /**
     * @return array<string, array{
     *   label: string,
     *   division: string,
     *   play_format: string,
     *   players_per_team: int,
     *   gender_restriction: string|null,
     *   requires_mixed: bool,
     *   min_age: int|null
     * }>
     */
    public static function eventDefinitions(): array
    {
        $events = [];

        foreach (self::divisionDefinitions() as $division => $divisionDef) {
            $ageLabel = match ($division) {
                self::DIVISION_OPEN => 'Open',
                self::DIVISION_35_PLUS => '35+',
                self::DIVISION_40_PLUS => '40+',
                self::DIVISION_50_PLUS => '50+',
                default => $division,
            };

            $templates = [
                'mens_singles' => [
                    'label' => "Men's Singles {$ageLabel}",
                    'play_format' => 'singles',
                    'players_per_team' => 1,
                    'gender_restriction' => 'male',
                    'requires_mixed' => false,
                ],
                'womens_singles' => [
                    'label' => "Women's Singles {$ageLabel}",
                    'play_format' => 'singles',
                    'players_per_team' => 1,
                    'gender_restriction' => 'female',
                    'requires_mixed' => false,
                ],
                'mens_doubles' => [
                    'label' => "Men's Doubles {$ageLabel}",
                    'play_format' => 'doubles',
                    'players_per_team' => 2,
                    'gender_restriction' => 'male',
                    'requires_mixed' => false,
                ],
                'womens_doubles' => [
                    'label' => "Women's Doubles {$ageLabel}",
                    'play_format' => 'doubles',
                    'players_per_team' => 2,
                    'gender_restriction' => 'female',
                    'requires_mixed' => false,
                ],
                'mixed_doubles' => [
                    'label' => "Mixed Doubles {$ageLabel}",
                    'play_format' => 'doubles',
                    'players_per_team' => 2,
                    'gender_restriction' => null,
                    'requires_mixed' => true,
                ],
                'skill_doubles' => [
                    'label' => "Skill Doubles {$ageLabel}",
                    'play_format' => 'doubles',
                    'players_per_team' => 2,
                    'gender_restriction' => null,
                    'requires_mixed' => false,
                ],
            ];

            foreach ($templates as $base => $template) {
                $eventKey = $division === self::DIVISION_OPEN
                    ? "{$base}_open"
                    : "{$base}_{$division}";

                $events[$eventKey] = array_merge($template, [
                    'division' => $division,
                    'min_age' => $divisionDef['min_age'],
                ]);
            }
        }

        return $events;
    }

    /**
     * @return list<string>
     */
    public static function allEventKeys(): array
    {
        return array_keys(self::eventDefinitions());
    }

    /**
     * @return list<string>
     */
    public static function allCategoryKeys(): array
    {
        $keys = [];

        foreach (self::allEventKeys() as $eventKey) {
            foreach (TournamentSkillLevel::ALL as $skillLevel) {
                $keys[] = self::makeCategoryKey($eventKey, $skillLevel);
            }
        }

        return $keys;
    }

    public static function makeCategoryKey(string $eventKey, string $skillLevel): string
    {
        return "{$eventKey}".self::KEY_SEPARATOR."{$skillLevel}";
    }

    /**
     * @return array{event_key: string, skill_level: string}
     */
    public static function parseCategoryKey(string $categoryKey): array
    {
        $separatorPos = strrpos($categoryKey, self::KEY_SEPARATOR);
        if ($separatorPos === false) {
            throw new \InvalidArgumentException("Invalid tournament category key: {$categoryKey}");
        }

        $eventKey = substr($categoryKey, 0, $separatorPos);
        $skillLevel = substr($categoryKey, $separatorPos + 1);

        if (! self::isValidEventKey($eventKey) || ! TournamentSkillLevel::isValid($skillLevel)) {
            throw new \InvalidArgumentException("Invalid tournament category key: {$categoryKey}");
        }

        return [
            'event_key' => $eventKey,
            'skill_level' => $skillLevel,
        ];
    }

    public static function isValidEventKey(string $eventKey): bool
    {
        return array_key_exists($eventKey, self::eventDefinitions());
    }

    public static function isValid(string $categoryKey): bool
    {
        try {
            self::parseCategoryKey($categoryKey);

            return true;
        } catch (\InvalidArgumentException) {
            return false;
        }
    }

    public static function eventLabel(string $eventKey): string
    {
        return self::eventDefinitions()[$eventKey]['label'] ?? $eventKey;
    }

    public static function label(string $categoryKey): string
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventLabel($parsed['event_key'])
            .' - '
            .TournamentSkillLevel::label($parsed['skill_level']);
    }

    public static function playersPerTeam(string $categoryKey): int
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventDefinitions()[$parsed['event_key']]['players_per_team'];
    }

    public static function requiresMixed(string $categoryKey): bool
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventDefinitions()[$parsed['event_key']]['requires_mixed'];
    }

    public static function genderRestriction(string $categoryKey): ?string
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventDefinitions()[$parsed['event_key']]['gender_restriction'];
    }

    public static function skillLevel(string $categoryKey): string
    {
        return self::parseCategoryKey($categoryKey)['skill_level'];
    }

    public static function eventKey(string $categoryKey): string
    {
        return self::parseCategoryKey($categoryKey)['event_key'];
    }

    public static function division(string $categoryKey): string
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventDefinitions()[$parsed['event_key']]['division'];
    }

    public static function playFormat(string $categoryKey): string
    {
        $parsed = self::parseCategoryKey($categoryKey);

        return self::eventDefinitions()[$parsed['event_key']]['play_format'];
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function catalogPayload(): array
    {
        return collect(self::allCategoryKeys())
            ->map(function (string $categoryKey) {
                $parsed = self::parseCategoryKey($categoryKey);
                $event = self::eventDefinitions()[$parsed['event_key']];
                $division = self::divisionDefinitions()[$event['division']];

                return [
                    'key' => $categoryKey,
                    'label' => self::label($categoryKey),
                    'eventKey' => $parsed['event_key'],
                    'eventLabel' => $event['label'],
                    'skillLevel' => $parsed['skill_level'],
                    'skillLabel' => TournamentSkillLevel::label($parsed['skill_level']),
                    'division' => $event['division'],
                    'divisionLabel' => $division['label'],
                    'playFormat' => $event['play_format'],
                    'playersPerTeam' => $event['players_per_team'],
                    'requiresMixed' => $event['requires_mixed'],
                    'genderRestriction' => $event['gender_restriction'],
                    'minAge' => $event['min_age'],
                ];
            })
            ->values()
            ->all();
    }

    /**
     * @return list<array{division: string, divisionLabel: string, events: list<array{eventKey: string, eventLabel: string, skillLevels: list<array{key: string, label: string, skillLevel: string, skillLabel: string}>}>}>
     */
    public static function groupedCatalogPayload(): array
    {
        $grouped = [];

        foreach (self::DIVISIONS as $division) {
            $divisionDef = self::divisionDefinitions()[$division];
            $events = [];

            foreach (self::eventDefinitions() as $eventKey => $event) {
                if ($event['division'] !== $division) {
                    continue;
                }

                $skillLevels = [];
                foreach (TournamentSkillLevel::ALL as $skillLevel) {
                    $categoryKey = self::makeCategoryKey($eventKey, $skillLevel);
                    $skillLevels[] = [
                        'key' => $categoryKey,
                        'label' => self::label($categoryKey),
                        'skillLevel' => $skillLevel,
                        'skillLabel' => TournamentSkillLevel::label($skillLevel),
                    ];
                }

                $events[] = [
                    'eventKey' => $eventKey,
                    'eventLabel' => $event['label'],
                    'playFormat' => $event['play_format'],
                    'playersPerTeam' => $event['players_per_team'],
                    'skillLevels' => $skillLevels,
                ];
            }

            $grouped[] = [
                'division' => $division,
                'divisionLabel' => $divisionDef['label'],
                'events' => $events,
            ];
        }

        return $grouped;
    }
}
