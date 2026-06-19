<?php

use App\Http\Controllers\Api\ChallengeCourtController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\CheckInController;
use App\Http\Controllers\Api\ClubPlayerController;
use App\Http\Controllers\Api\LeaderboardController;
use App\Http\Controllers\Api\MatchController;
use App\Http\Controllers\Api\PlayerController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\SessionPresetController;
use App\Http\Controllers\Api\TournamentController;
use App\Http\Controllers\Api\SessionMembershipController;
use App\Http\Middleware\VerifyAdminPin;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['status' => 'ok']));

Route::get('/health/db', function () {
    try {
        \Illuminate\Support\Facades\DB::connection()->getPdo();
        $hasSessions = \Illuminate\Support\Facades\Schema::hasTable('play_sessions');

        return response()->json([
            'status' => 'ok',
            'database' => 'connected',
            'migrations' => $hasSessions ? 'ready' : 'pending',
        ]);
    } catch (\Throwable $exception) {
        return response()->json([
            'status' => 'error',
            'database' => 'not_connected',
            'message' => 'Add DB_HOST, DB_DATABASE, DB_USERNAME, and DB_PASSWORD in Vercel, then redeploy.',
        ], 503);
    }
});

Route::get('/sessions/active', [SessionController::class, 'active']);
Route::get('/sessions/{session}/state', [SessionController::class, 'state']);

Route::get('/leaderboard/all-time', [LeaderboardController::class, 'allTime']);
Route::get('/leaderboard/monthly', [LeaderboardController::class, 'monthly']);
Route::get('/leaderboard/season', [LeaderboardController::class, 'season']);
Route::get('/leaderboard/session/{session}', [LeaderboardController::class, 'session']);

Route::prefix('check-in')->group(function () {
    Route::get('/session', [CheckInController::class, 'session']);
    Route::get('/session-players', [CheckInController::class, 'sessionPlayers']);
    Route::get('/players', [CheckInController::class, 'players']);
    Route::get('/status', [CheckInController::class, 'status']);
    Route::post('/register', [CheckInController::class, 'register']);
    Route::post('/join', [CheckInController::class, 'join']);
    Route::post('/step-out', [CheckInController::class, 'stepOut']);
    Route::post('/step-back', [CheckInController::class, 'stepBack']);
});

Route::get('/tournaments/active', [TournamentController::class, 'active']);
Route::get('/tournaments/{tournament}', [TournamentController::class, 'show']);

Route::middleware(VerifyAdminPin::class)->group(function () {
    Route::get('/players', [ClubPlayerController::class, 'index']);
    Route::get('/players/{clubPlayer}', [ClubPlayerController::class, 'show']);
    Route::post('/players', [ClubPlayerController::class, 'store']);
    Route::delete('/players/{clubPlayer}', [ClubPlayerController::class, 'destroy']);

    Route::post('/session/join', [SessionMembershipController::class, 'join']);
    Route::post('/session/remove', [SessionMembershipController::class, 'remove']);

    Route::get('/sessions/calendar', [SessionController::class, 'calendar']);
    Route::get('/sessions/history', [SessionController::class, 'historyByDate']);
    Route::get('/session-presets', [SessionPresetController::class, 'index']);
    Route::post('/session-presets', [SessionPresetController::class, 'store']);
    Route::put('/session-presets/{preset}', [SessionPresetController::class, 'update']);
    Route::delete('/session-presets/{preset}', [SessionPresetController::class, 'destroy']);

    Route::post('/sessions', [SessionController::class, 'store']);
    Route::patch('/sessions/{session}/settings', [SessionController::class, 'updateSettings']);
    Route::post('/sessions/{session}/registrations/{clubPlayer}/mark-paid', [PaymentController::class, 'markPaid']);
    Route::post('/sessions/{session}/registrations/{clubPlayer}/mark-waived', [PaymentController::class, 'markWaived']);
    Route::post('/sessions/{session}/registrations/{clubPlayer}/activate', [PaymentController::class, 'activate']);
    Route::get('/admin/revenue', [PaymentController::class, 'revenue']);
    Route::get('/admin/revenue/export', [PaymentController::class, 'exportRevenue']);
    Route::post('/sessions/{session}/end', [SessionController::class, 'end']);
    Route::get('/sessions/{session}/history', [SessionController::class, 'history']);
    Route::get('/sessions/{session}/export', [SessionController::class, 'export']);
    Route::get('/sessions/{session}/report', [SessionController::class, 'report']);
    Route::post('/sessions/{session}/players', [PlayerController::class, 'store']);
    Route::patch('/sessions/{session}/players/{player}', [PlayerController::class, 'update']);
    Route::delete('/sessions/{session}/players/{player}', [PlayerController::class, 'destroy']);
    Route::post('/sessions/{session}/matches/{match}/score', [MatchController::class, 'score']);
    Route::post('/sessions/{session}/courts/{court}/assign', [MatchController::class, 'assign']);
    Route::post('/sessions/{session}/courts/{court}/assign-next', [MatchController::class, 'assignNext']);
    Route::post('/sessions/{session}/courts/{court}/players/{player}/remove', [MatchController::class, 'removePlayer']);

    Route::patch('/sessions/{session}/challenge-court/configure', [ChallengeCourtController::class, 'configure']);
    Route::post('/sessions/{session}/challenge-court/open', [ChallengeCourtController::class, 'open']);
    Route::post('/sessions/{session}/challenge-court/close', [ChallengeCourtController::class, 'close']);
    Route::post('/sessions/{session}/challenge-court/join', [ChallengeCourtController::class, 'join']);
    Route::post('/sessions/{session}/challenge-court/teams/{team}/return', [ChallengeCourtController::class, 'returnToSession']);
    Route::delete('/sessions/{session}/challenge-court/teams/{team}', [ChallengeCourtController::class, 'removeTeam']);
    Route::patch('/sessions/{session}/challenge-court/reorder', [ChallengeCourtController::class, 'reorder']);
    Route::post('/sessions/{session}/courts/{court}/assign-challenge-next', [ChallengeCourtController::class, 'assignNext']);

    Route::get('/tournaments', [TournamentController::class, 'index']);
    Route::post('/tournaments', [TournamentController::class, 'store']);
    Route::patch('/tournaments/{tournament}', [TournamentController::class, 'update']);
    Route::delete('/tournaments/{tournament}', [TournamentController::class, 'destroy']);
    Route::post('/tournaments/{tournament}/start', [TournamentController::class, 'start']);
    Route::post('/tournaments/{tournament}/categories/{categoryKey}/teams', [TournamentController::class, 'registerTeam']);
    Route::post('/tournaments/{tournament}/categories/{categoryKey}/draw-lots', [TournamentController::class, 'drawLots']);
    Route::delete('/tournaments/{tournament}/teams/{team}', [TournamentController::class, 'removeTeam']);
    Route::patch('/tournaments/{tournament}/players/{clubPlayer}', [TournamentController::class, 'updatePlayer']);
    Route::post('/tournaments/{tournament}/matches/{tournamentMatch}/score', [TournamentController::class, 'score']);
    Route::post('/tournaments/{tournament}/matches/{tournamentMatch}/activate-court', [TournamentController::class, 'activateCourt']);
    Route::post('/tournaments/{tournament}/matches/{tournamentMatch}/assign-court', [TournamentController::class, 'assignCourt']);
});
