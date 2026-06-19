<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->unsignedInteger('total_points_scored')->default(0)->after('total_losses');
            $table->unsignedInteger('total_points_allowed')->default(0)->after('total_points_scored');
        });

        Schema::table('session_players', function (Blueprint $table) {
            $table->unsignedInteger('session_points_scored')->default(0)->after('session_losses');
            $table->unsignedInteger('session_points_allowed')->default(0)->after('session_points_scored');
        });
    }

    public function down(): void
    {
        Schema::table('session_players', function (Blueprint $table) {
            $table->dropColumn(['session_points_scored', 'session_points_allowed']);
        });

        Schema::table('club_players', function (Blueprint $table) {
            $table->dropColumn(['total_points_scored', 'total_points_allowed']);
        });
    }
};
