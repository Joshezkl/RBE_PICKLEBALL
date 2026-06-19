<?php

namespace App\Services;

use App\Models\Tournament;
use App\Support\TournamentCategory as TournamentCategorySupport;
use Illuminate\Support\Facades\DB;

class TournamentDrawLotsService
{
    public function __construct(
        private TournamentService $tournamentService,
    ) {}

    /**
     * @param  list<string>  $playerNames
     * @param  list<string>|null  $genders
     * @return list<array{names: list<string>, genders: list<string>}>
     */
    public function buildPairs(
        string $categoryKey,
        array $playerNames,
        ?array $genders = null,
    ): array {
        if (TournamentCategorySupport::playersPerTeam($categoryKey) !== 2) {
            throw new \InvalidArgumentException('Draw lots is only available for doubles categories');
        }

        $names = array_values(array_filter(
            array_map('trim', $playerNames),
            fn (string $name) => $name !== '',
        ));

        if (count($names) < 2) {
            throw new \InvalidArgumentException('At least 2 players are required for draw lots');
        }

        if (TournamentCategorySupport::requiresMixed($categoryKey)) {
            return $this->pairMixed($names, $genders);
        }

        if (count($names) % 2 !== 0) {
            throw new \InvalidArgumentException(
                'Draw lots requires an even number of players. Found '.count($names).'.'
            );
        }

        $indices = range(0, count($names) - 1);
        shuffle($indices);

        $defaultGender = TournamentCategorySupport::genderRestriction($categoryKey) ?? 'male';
        $pairs = [];

        for ($i = 0; $i < count($names); $i += 2) {
            $firstIndex = $indices[$i];
            $secondIndex = $indices[$i + 1];
            $pairGenders = [
                $genders[$firstIndex] ?? $defaultGender,
                $genders[$secondIndex] ?? $defaultGender,
            ];

            $pairs[] = [
                'names' => [$names[$firstIndex], $names[$secondIndex]],
                'genders' => $pairGenders,
            ];
        }

        return $pairs;
    }

    /**
     * @param  list<string>  $playerNames
     * @param  list<string>|null  $genders
     * @return list<array{names: list<string>, genders: list<string>}>
     */
    private function pairMixed(array $playerNames, ?array $genders): array
    {
        if ($genders === null || count($genders) !== count($playerNames)) {
            throw new \InvalidArgumentException(
                'Mixed doubles draw lots requires a gender for each player. Use "Name (M)" or "Name (F)".'
            );
        }

        $males = [];
        $females = [];

        foreach ($playerNames as $index => $name) {
            $gender = $genders[$index];
            if ($gender === 'male') {
                $males[] = $name;
            } elseif ($gender === 'female') {
                $females[] = $name;
            } else {
                throw new \InvalidArgumentException("Invalid gender for {$name}");
            }
        }

        if (count($males) === 0 || count($females) === 0) {
            throw new \InvalidArgumentException(
                'Mixed doubles draw lots needs at least one male and one female player'
            );
        }

        if (count($males) !== count($females)) {
            throw new \InvalidArgumentException(
                'Mixed doubles draw lots needs equal male and female counts. '
                .'Found '.count($males).' male and '.count($females).' female.'
            );
        }

        shuffle($males);
        shuffle($females);

        $pairs = [];
        for ($i = 0; $i < count($males); $i++) {
            $pairs[] = [
                'names' => [$males[$i], $females[$i]],
                'genders' => ['male', 'female'],
            ];
        }

        return $pairs;
    }

    /**
     * @param  list<string>  $playerNames
     * @param  list<string>|null  $genders
     * @return list<array{teamId: int, displayName: string, names: list<string>}>
     */
    public function drawAndRegister(
        Tournament $tournament,
        string $categoryKey,
        array $playerNames,
        ?array $genders = null,
    ): array {
        $pairs = $this->buildPairs($categoryKey, $playerNames, $genders);

        return DB::transaction(function () use ($tournament, $categoryKey, $pairs) {
            $registered = [];

            foreach ($pairs as $pair) {
                $team = $this->tournamentService->registerTeamFromNames(
                    $tournament,
                    $categoryKey,
                    $pair['names'],
                    $pair['genders'],
                );

                $registered[] = [
                    'teamId' => $team->id,
                    'displayName' => $team->display_name,
                    'names' => $pair['names'],
                ];
            }

            return $registered;
        });
    }
}
