<?php

namespace App\Providers;

use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Tournament;
use App\Models\TournamentMatch;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Route::bind('session', fn (string $value) => PlaySession::query()->findOrFail($value));
        Route::bind('match', fn (string $value) => MatchGame::query()->findOrFail($value));
        Route::bind('tournament', fn (string $value) => Tournament::query()->findOrFail($value));
        Route::bind('tournamentMatch', fn (string $value) => TournamentMatch::query()->findOrFail($value));
    }
}
