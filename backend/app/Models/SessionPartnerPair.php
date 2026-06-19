<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Collection;

class SessionPartnerPair extends Model
{
    protected $fillable = [
        'play_session_id',
        'player_one_id',
        'player_two_id',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(PlaySession::class, 'play_session_id');
    }

    public function playerOne(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'player_one_id');
    }

    public function playerTwo(): BelongsTo
    {
        return $this->belongsTo(Player::class, 'player_two_id');
    }

    /**
     * @return array{0: int, 1: int}
     */
    public static function canonicalIds(int $playerAId, int $playerBId): array
    {
        return $playerAId < $playerBId
            ? [$playerAId, $playerBId]
            : [$playerBId, $playerAId];
    }

    public static function pairKey(int $playerAId, int $playerBId): string
    {
        [$low, $high] = self::canonicalIds($playerAId, $playerBId);

        return "{$low}:{$high}";
    }

    public static function record(int $sessionId, int $playerAId, int $playerBId): void
    {
        [$low, $high] = self::canonicalIds($playerAId, $playerBId);

        self::query()->firstOrCreate([
            'play_session_id' => $sessionId,
            'player_one_id' => $low,
            'player_two_id' => $high,
        ]);
    }

    /**
     * @param  Collection<int, Player>|array<int, Player>  $players
     * @return array<string, true>
     */
    public static function partnershipSetForSession(int $sessionId, Collection|array $players): array
    {
        $playerIds = collect($players)->pluck('id')->filter()->unique()->values()->all();

        if ($playerIds === []) {
            return [];
        }

        $pairs = self::query()
            ->where('play_session_id', $sessionId)
            ->where(function ($query) use ($playerIds) {
                $query->whereIn('player_one_id', $playerIds)
                    ->orWhereIn('player_two_id', $playerIds);
            })
            ->get(['player_one_id', 'player_two_id']);

        $set = [];
        foreach ($pairs as $pair) {
            $set[self::pairKey($pair->player_one_id, $pair->player_two_id)] = true;
        }

        return $set;
    }
}
