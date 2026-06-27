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
        if (getenv('VERCEL')) {
            config([
                'logging.default' => 'stderr',
            ]);
        }

        Route::bind('session', fn (string $value) => PlaySession::query()->findOrFail($value));
        Route::bind('match', fn (string $value) => MatchGame::query()->findOrFail($value));
        Route::bind('tournament', fn (string $value) => Tournament::query()->findOrFail($value));
        Route::bind('tournamentMatch', fn (string $value) => TournamentMatch::query()->findOrFail($value));

        $this->registerStateCacheInvalidation();
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
}
