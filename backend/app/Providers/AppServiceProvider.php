<?php

namespace App\Providers;

use App\Models\ChallengeCourtTeam;
use App\Models\ClubPlayer;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\Payment;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use App\Models\SessionPartnerPair;
use App\Models\SessionPlayer;
use App\Models\Tournament;
use App\Models\TournamentMatch;
use App\Support\SessionCacheInvalidator;
use App\Services\TournamentStateService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(SessionCacheInvalidator::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if (getenv('VERCEL') || getenv('VERCEL_ENV')) {
            $tmp = sys_get_temp_dir().'/rbe';
            $cacheDir = "{$tmp}/cache/data";

            if (! is_dir($cacheDir)) {
                mkdir($cacheDir, 0755, true);
            }

            // Database-backed cache adds a remote round trip on every poll hit.
            // File cache in /tmp persists across warm serverless invocations.
            $cacheStore = env('CACHE_STORE', 'file');
            if ($cacheStore === 'database') {
                $cacheStore = 'file';
            }

            config([
                'logging.default' => 'stderr',
                'cache.default' => $cacheStore,
                'cache.stores.file.path' => $cacheDir,
                'cache.stores.file.lock_path' => $cacheDir,
            ]);
        }

        Route::bind('session', fn (string $value) => PlaySession::query()->findOrFail($value));
        Route::bind('match', fn (string $value) => MatchGame::query()->findOrFail($value));
        Route::bind('tournament', fn (string $value) => Tournament::query()->findOrFail($value));
        Route::bind('tournamentMatch', fn (string $value) => TournamentMatch::query()->findOrFail($value));

        $this->registerStateCacheInvalidation();
        $this->registerTournamentCacheInvalidation();
    }

    /**
     * Invalidate cached session state / leaderboards whenever an underlying
     * model changes. Hooking the data layer (instead of controllers) guarantees
     * cached reads never serve data older than the latest write, even on paths
     * that mutate and then short-circuit without rebuilding state.
     */
    private function registerStateCacheInvalidation(): void
    {
        // Models whose changes affect the live session payload.
        $sessionScoped = [
            Player::class,
            QueueEntry::class,
            Court::class,
            MatchGame::class,
            SessionPlayer::class,
            Payment::class,
            ChallengeCourtTeam::class,
            SessionPartnerPair::class,
        ];

        // Models whose changes also affect leaderboard rankings.
        $leaderboardScoped = [
            MatchGame::class,
            SessionPlayer::class,
            PlaySession::class,
        ];

        $invalidator = fn (): SessionCacheInvalidator => $this->app->make(SessionCacheInvalidator::class);

        foreach ($sessionScoped as $modelClass) {
            $mark = function (Model $model) use ($invalidator, $leaderboardScoped): void {
                $sessionId = $model->getAttribute('play_session_id');
                $invalidator()->markSession($sessionId !== null ? (int) $sessionId : null);

                if (in_array($model::class, $leaderboardScoped, true)) {
                    $invalidator()->markLeaderboard($sessionId !== null ? (int) $sessionId : null);
                }
            };

            $modelClass::saved($mark);
            $modelClass::deleted($mark);
        }

        $playSessionMark = function (PlaySession $session) use ($invalidator): void {
            $invalidator()->markSession((int) $session->id);
            $invalidator()->markLeaderboard((int) $session->id);
        };
        PlaySession::saved($playSessionMark);
        PlaySession::deleted($playSessionMark);

        // ClubPlayer carries denormalized lifetime stats but no session id; its
        // changes only affect leaderboards.
        $clubPlayerMark = function () use ($invalidator): void {
            $invalidator()->markLeaderboard();
        };
        ClubPlayer::saved($clubPlayerMark);
        ClubPlayer::deleted($clubPlayerMark);

        // Flush once, after the response is sent.
        $this->app->terminating(function (): void {
            $this->app->make(SessionCacheInvalidator::class)->flush();
        });
    }

    private function registerTournamentCacheInvalidation(): void
    {
        $invalidate = function (?int $tournamentId): void {
            if ($tournamentId !== null) {
                TournamentStateService::invalidate($tournamentId);
            }
        };

        Tournament::saved(fn (Tournament $tournament) => $invalidate((int) $tournament->id));
        Tournament::deleted(fn (Tournament $tournament) => $invalidate((int) $tournament->id));

        foreach ([TournamentMatch::class] as $modelClass) {
            $modelClass::saved(function (Model $model) use ($invalidate): void {
                $invalidate($model->getAttribute('tournament_id') !== null
                    ? (int) $model->getAttribute('tournament_id')
                    : null);
            });
            $modelClass::deleted(function (Model $model) use ($invalidate): void {
                $invalidate($model->getAttribute('tournament_id') !== null
                    ? (int) $model->getAttribute('tournament_id')
                    : null);
            });
        }
    }
}
