<?php

namespace App\Services;

use App\Models\ClubPlayer;
use App\Models\Tournament;
use App\Models\TournamentCategory;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use App\Models\TournamentTeamMember;
use App\Support\TournamentCategory as TournamentCategorySupport;
use App\Support\TournamentSkillLevel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TournamentService
{
    public function __construct(
        private TournamentScheduleService $scheduleService,
        private TournamentStateService $stateService,
        private TournamentCourtService $courtService,
        private ClubPlayerService $clubPlayerService,
    ) {}

    /**
     * @param  array{name?: string, group_count?: int, court_count?: int, categories?: list<string>}  $data
     */
    public function create(array $data): Tournament
    {
        return DB::transaction(function () use ($data) {
            $tournament = Tournament::query()->create([
                'name' => $data['name'] ?? 'Tournament',
                'status' => 'draft',
                'registration_token' => Str::random(32),
                'group_count' => $data['group_count'] ?? 4,
                'court_count' => $data['court_count'] ?? 4,
            ]);

            $this->seedCategories($tournament, $data['categories'] ?? []);

            return $tournament->fresh();
        });
    }

    /**
     * @param  array{name?: string, group_count?: int, court_count?: int, categories?: list<string>}  $data
     */
    public function update(Tournament $tournament, array $data): Tournament
    {
        if (array_key_exists('court_count', $data)) {
            $this->applyCourtCount($tournament, (int) $data['court_count']);
        }

        if (! in_array($tournament->status, ['draft', 'setup'], true)) {
            return $tournament->fresh();
        }

        return DB::transaction(function () use ($tournament, $data) {
            $tournament->update(array_filter([
                'name' => $data['name'] ?? null,
                'group_count' => $data['group_count'] ?? null,
            ], fn ($value) => $value !== null));

            if (array_key_exists('categories', $data)) {
                $this->syncEnabledCategories($tournament, $data['categories']);
            }

            return $tournament->fresh();
        });
    }

    public function applyCourtCount(Tournament $tournament, int $courtCount): void
    {
        if ($tournament->status === 'completed') {
            throw new \RuntimeException('Cannot change courts for a completed tournament');
        }

        $courtCount = max(1, min(12, $courtCount));
        $currentCount = (int) $tournament->court_count;

        if ($courtCount === $currentCount) {
            return;
        }

        DB::transaction(function () use ($tournament, $courtCount, $currentCount) {
            $isLive = in_array($tournament->status, ['round_robin', 'single_elimination', 'final_round_robin'], true);

            if ($isLive) {
                $this->courtService->clearCourtAssignments($tournament);
            }

            $tournament->update(['court_count' => $courtCount]);

        });
    }

    public function start(Tournament $tournament): Tournament
    {
        if (! in_array($tournament->status, ['draft', 'setup'], true)) {
            throw new \RuntimeException('Tournament has already started');
        }

        $enabled = $tournament->categories()->where('is_enabled', true)->get();

        if ($enabled->isEmpty()) {
            throw new \InvalidArgumentException('Enable at least one category before starting');
        }

        $startedAny = false;

        DB::transaction(function () use ($enabled, $tournament, &$startedAny) {
            foreach ($enabled as $category) {
                $teamCount = $category->teams()->count();
                if ($teamCount < 2) {
                    continue;
                }

                $this->scheduleService->assignGroupsRandomly($category, $tournament);
                $this->scheduleService->generateRoundRobin($category);
                $startedAny = true;
            }

            if (! $startedAny) {
                throw new \InvalidArgumentException(
                    'Each enabled category needs at least two registered teams to start'
                );
            }

            $tournament->update([
                'status' => 'round_robin',
                'started_at' => now(),
            ]);
        });

        return $tournament->fresh();
    }

    /**
     * @param  list<int>  $clubPlayerIds
     */
    public function registerTeam(
        Tournament $tournament,
        string $categoryKey,
        array $clubPlayerIds,
    ): TournamentTeam {
        if (! TournamentCategorySupport::isValid($categoryKey)) {
            throw new \InvalidArgumentException('Invalid tournament category');
        }

        $category = $this->resolveCategory($tournament, $categoryKey);

        if (! $category->is_enabled) {
            throw new \InvalidArgumentException('Category is not enabled for this tournament');
        }

        $isLiveRoundRobin = $tournament->status === 'round_robin'
            && $category->phase === 'round_robin';

        if (! in_array($tournament->status, ['draft', 'setup', 'round_robin'], true)) {
            throw new \RuntimeException('Cannot register teams for this tournament phase');
        }

        if ($tournament->status === 'round_robin' && ! $isLiveRoundRobin) {
            throw new \RuntimeException('Cannot register teams for a category that has advanced past round robin');
        }

        $required = TournamentCategorySupport::playersPerTeam($categoryKey);
        $uniqueIds = array_values(array_unique($clubPlayerIds));
        $requiredSkill = TournamentCategorySupport::skillLevel($categoryKey);

        if (count($uniqueIds) !== $required) {
            throw new \InvalidArgumentException("This category requires exactly {$required} player(s) per team");
        }

        $players = ClubPlayer::query()->whereIn('id', $uniqueIds)->get();

        if ($players->count() !== $required) {
            throw new \InvalidArgumentException('One or more players were not found');
        }

        foreach ($players as $player) {
            if ($player->skill_level !== $requiredSkill) {
                throw new \InvalidArgumentException(
                    TournamentCategorySupport::label($categoryKey)
                    .' requires '
                    .TournamentSkillLevel::label($requiredSkill)
                    .' players'
                );
            }
        }

        $genderRestriction = TournamentCategorySupport::genderRestriction($categoryKey);
        if ($genderRestriction !== null) {
            foreach ($players as $player) {
                if ($player->gender !== $genderRestriction) {
                    throw new \InvalidArgumentException(
                        TournamentCategorySupport::eventLabel(TournamentCategorySupport::eventKey($categoryKey))
                        .' requires '
                        .$genderRestriction
                        .' players only'
                    );
                }
            }
        }

        if (TournamentCategorySupport::requiresMixed($categoryKey)) {
            $genders = $players->pluck('gender')->filter()->unique();
            if ($genders->count() < 2) {
                throw new \InvalidArgumentException('Mixed doubles teams require one male and one female player');
            }
        }

        $displayName = $players->map(fn (ClubPlayer $p) => $p->publicName())->join(' / ');

        $team = DB::transaction(function () use (
            $tournament,
            $category,
            $uniqueIds,
            $displayName,
            $isLiveRoundRobin,
        ) {
            $existing = TournamentTeamMember::query()
                ->whereIn('club_player_id', $uniqueIds)
                ->whereHas('team', fn ($q) => $q->where('tournament_category_id', $category->id))
                ->exists();

            if ($existing) {
                throw new \InvalidArgumentException('One or more players are already registered in this category');
            }

            $team = TournamentTeam::query()->create([
                'tournament_id' => $tournament->id,
                'tournament_category_id' => $category->id,
                'display_name' => $displayName,
            ]);

            foreach ($uniqueIds as $playerId) {
                TournamentTeamMember::query()->create([
                    'tournament_team_id' => $team->id,
                    'club_player_id' => $playerId,
                ]);
            }

            if ($tournament->status === 'draft') {
                $tournament->update(['status' => 'setup']);
            }

            if ($isLiveRoundRobin) {
                $this->scheduleService->integrateLateRoundRobinTeam(
                    $category->fresh(),
                    $team->fresh(['members.clubPlayer']),
                );
            }

            return $team->fresh(['members.clubPlayer']);
        });

        return $team;
    }

    /**
     * @param  list<string>  $playerNames
     * @param  list<string>  $genders
     */
    public function registerTeamFromNames(
        Tournament $tournament,
        string $categoryKey,
        array $playerNames,
        array $genders,
    ): TournamentTeam {
        $required = TournamentCategorySupport::playersPerTeam($categoryKey);

        if (count($playerNames) !== $required) {
            throw new \InvalidArgumentException("This category requires exactly {$required} player(s) per team");
        }

        if (count($genders) !== $required) {
            throw new \InvalidArgumentException("This category requires exactly {$required} gender value(s)");
        }

        $requiredSkill = TournamentCategorySupport::skillLevel($categoryKey);
        $playerIds = [];

        foreach ($playerNames as $index => $name) {
            $player = $this->clubPlayerService->registerTournamentPlayer(
                $name,
                $requiredSkill,
                $genders[$index],
            );
            $playerIds[] = $player->id;
        }

        return $this->registerTeam($tournament, $categoryKey, $playerIds);
    }

    public function removeTeam(Tournament $tournament, TournamentTeam $team): void
    {
        if ($team->tournament_id !== $tournament->id) {
            throw new \InvalidArgumentException('Team does not belong to this tournament');
        }

        if ($tournament->status === 'completed') {
            throw new \RuntimeException('Cannot remove teams from a completed tournament');
        }

        $category = $team->category()->firstOrFail();
        $isLiveRoundRobin = $tournament->status === 'round_robin'
            && $category->phase === 'round_robin';

        if (! in_array($tournament->status, ['draft', 'setup', 'round_robin'], true)) {
            throw new \RuntimeException('Cannot remove teams during this tournament phase');
        }

        if ($tournament->status === 'round_robin' && ! $isLiveRoundRobin) {
            throw new \RuntimeException('Cannot remove teams from a category that has advanced past round robin');
        }

        $memberIds = $team->members()->pluck('club_player_id')->all();

        if ($isLiveRoundRobin) {
            $this->scheduleService->withdrawRoundRobinTeam($category, $team);
            $team->delete();
        } else {
            $team->delete();
        }

        $this->clubPlayerService->purgeOrphanedTournamentOnlyPlayers($memberIds);
    }

    public function updatePlayerName(
        Tournament $tournament,
        ClubPlayer $clubPlayer,
        string $name,
    ): void {
        if ($tournament->status === 'completed') {
            throw new \RuntimeException('Cannot edit players for a completed tournament');
        }

        $trimmed = trim($name);
        if ($trimmed === '') {
            throw new \InvalidArgumentException('Player name is required');
        }

        $isRegistered = TournamentTeamMember::query()
            ->where('club_player_id', $clubPlayer->id)
            ->whereHas('team', fn ($query) => $query->where('tournament_id', $tournament->id))
            ->exists();

        if (! $isRegistered) {
            throw new \InvalidArgumentException('Player is not registered in this tournament');
        }

        $clubPlayer->update(['display_name' => $trimmed]);

        $teams = TournamentTeam::query()
            ->where('tournament_id', $tournament->id)
            ->whereHas('members', fn ($query) => $query->where('club_player_id', $clubPlayer->id))
            ->with('members.clubPlayer')
            ->get();

        foreach ($teams as $team) {
            $displayName = $team->members
                ->map(fn (TournamentTeamMember $member) => $member->clubPlayer?->publicName() ?? 'Player')
                ->join(' / ');

            $team->update(['display_name' => $displayName]);
        }
    }

    public function delete(Tournament $tournament): void
    {
        $memberIds = TournamentTeamMember::query()
            ->whereHas('team', fn ($query) => $query->where('tournament_id', $tournament->id))
            ->pluck('club_player_id')
            ->all();

        $tournament->delete();

        $this->clubPlayerService->purgeOrphanedTournamentOnlyPlayers($memberIds);
    }

    /**
     * @return array<string, mixed>
     */
    public function state(Tournament $tournament): array
    {
        return $this->stateService->build($tournament);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function list(): array
    {
        return Tournament::query()
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (Tournament $t) => [
                'id' => $t->id,
                'name' => $t->name,
                'status' => $t->status,
                'groupCount' => $t->group_count,
                'startedAt' => $t->started_at?->toIso8601String(),
                'endedAt' => $t->ended_at?->toIso8601String(),
            ])
            ->all();
    }

    private function seedCategories(Tournament $tournament, array $enabledKeys): void
    {
        $now = now();
        $rows = array_map(
            fn (string $key) => [
                'tournament_id' => $tournament->id,
                'category_key' => $key,
                'is_enabled' => in_array($key, $enabledKeys, true),
                'phase' => 'setup',
                'created_at' => $now,
                'updated_at' => $now,
            ],
            TournamentCategorySupport::allCategoryKeys(),
        );

        foreach (array_chunk($rows, 50) as $chunk) {
            TournamentCategory::query()->insert($chunk);
        }
    }

    private function syncEnabledCategories(Tournament $tournament, array $enabledKeys): void
    {
        foreach ($enabledKeys as $key) {
            if (! TournamentCategorySupport::isValid($key)) {
                throw new \InvalidArgumentException("Invalid category: {$key}");
            }
        }

        $tournament->categories()->update(['is_enabled' => false]);

        if ($enabledKeys !== []) {
            $tournament->categories()
                ->whereIn('category_key', $enabledKeys)
                ->update(['is_enabled' => true]);
        }
    }

    private function resolveCategory(Tournament $tournament, string $categoryKey): TournamentCategory
    {
        return $tournament->categories()
            ->where('category_key', $categoryKey)
            ->firstOrFail();
    }
}
