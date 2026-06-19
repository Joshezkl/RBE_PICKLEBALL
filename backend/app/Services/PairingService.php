<?php

namespace App\Services;

use App\Models\PlaySession;
use App\Models\Player;
use App\Models\SessionPartnerPair;
use App\Support\MatchMode;
use Illuminate\Support\Collection;

class PairingService
{
    private const SAME_TEAM_REPEAT_PENALTY = 10000;

    private const OPPOSITE_TEAM_REPEAT_BONUS = -200;

    private const SPLITS = [
        ['teamA' => [0, 1], 'teamB' => [2, 3]],
        ['teamA' => [0, 2], 'teamB' => [1, 3]],
        ['teamA' => [0, 3], 'teamB' => [1, 2]],
    ];

    public function __construct(private MatchModeService $matchModeService) {}

    /**
     * @param  Collection<int, Player>  $players
     * @return array{teamA: array<int, Player>, teamB: array<int, Player>}
     */
    public function formTeams(Collection $players, PlaySession $session): array
    {
        if ($session->play_format === 'singles') {
            return [
                'teamA' => [$players->values()->get(0)],
                'teamB' => [$players->values()->get(1)],
            ];
        }

        $preferMixed = MatchMode::prefersMixedTeams($session->match_mode);
        $partnerPairs = $session->id
            ? SessionPartnerPair::partnershipSetForSession($session->id, $players)
            : [];

        $bestSplits = [];
        $bestScore = PHP_INT_MAX;

        foreach ($this->permutations($players->values()->all()) as $list) {
            foreach (self::SPLITS as $split) {
                $teamA = [$list[$split['teamA'][0]], $list[$split['teamA'][1]]];
                $teamB = [$list[$split['teamB'][0]], $list[$split['teamB'][1]]];
                $score = $this->scoreSplit($teamA, $teamB, $preferMixed, $partnerPairs);

                if ($score < $bestScore) {
                    $bestScore = $score;
                    $bestSplits = [['teamA' => $teamA, 'teamB' => $teamB]];
                } elseif ($score === $bestScore) {
                    $bestSplits[] = ['teamA' => $teamA, 'teamB' => $teamB];
                }
            }
        }

        if ($bestSplits === []) {
            $list = $players->values()->all();

            return [
                'teamA' => [$list[0], $list[1]],
                'teamB' => [$list[2], $list[3]],
            ];
        }

        return $bestSplits[array_rand($bestSplits)];
    }

    /**
     * @param  array<int, Player>  $teamA
     * @param  array<int, Player>  $teamB
     */
    public function updatePartnerState(PlaySession $session, array $teamA, array $teamB): void
    {
        if (count($teamA) === 2) {
            $this->setPartners($session, $teamA[0], $teamA[1]);
        }
        if (count($teamB) === 2) {
            $this->setPartners($session, $teamB[0], $teamB[1]);
        }
    }

    /**
     * @param  array<int, Player>  $items
     * @return array<int, array<int, Player>>
     */
    private function permutations(array $items): array
    {
        if (count($items) <= 1) {
            return [$items];
        }

        $result = [];
        foreach ($items as $index => $item) {
            $rest = $items;
            array_splice($rest, $index, 1);
            foreach ($this->permutations($rest) as $perm) {
                $result[] = array_merge([$item], $perm);
            }
        }

        return $result;
    }

    /**
     * @param  array<int, Player>  $teamA
     * @param  array<int, Player>  $teamB
     * @param  array<string, true>  $partnerPairs
     */
    private function scoreSplit(array $teamA, array $teamB, bool $preferMixed, array $partnerPairs): int
    {
        $score = 0;

        if ($preferMixed) {
            $score += $this->mixedGenderScore($teamA[0], $teamA[1]);
            $score += $this->mixedGenderScore($teamB[0], $teamB[1]);
        }

        $all = array_merge($teamA, $teamB);
        for ($i = 0; $i < count($all); $i++) {
            for ($j = $i + 1; $j < count($all); $j++) {
                $sameTeam = ($i < 2 && $j < 2) || ($i >= 2 && $j >= 2);
                $score += $this->pairScore($all[$i], $all[$j], $sameTeam, $partnerPairs);
            }
        }

        return $score;
    }

    /**
     * @param  array<string, true>  $partnerPairs
     */
    private function pairScore(Player $a, Player $b, bool $sameTeam, array $partnerPairs): int
    {
        if (! isset($partnerPairs[SessionPartnerPair::pairKey($a->id, $b->id)])) {
            return 0;
        }

        return $sameTeam
            ? self::SAME_TEAM_REPEAT_PENALTY
            : self::OPPOSITE_TEAM_REPEAT_BONUS;
    }

    private function setPartners(PlaySession $session, Player $a, Player $b): void
    {
        $a->update(['last_partner_id' => $b->id]);
        $b->update(['last_partner_id' => $a->id]);

        if ($session->id) {
            SessionPartnerPair::record($session->id, $a->id, $b->id);
        }
    }

    private function mixedGenderScore(Player $a, Player $b): int
    {
        if ($a->gender && $b->gender && $a->gender !== $b->gender) {
            return -150;
        }

        return 100;
    }
}
