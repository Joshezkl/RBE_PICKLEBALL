<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->boolean('is_guest')->default(false)->after('gender');
            $table->string('display_name')->nullable()->after('is_guest');
        });

        Schema::table('players', function (Blueprint $table) {
            $table->string('availability')->default('active')->after('is_active');
            $table->string('away_queue_type')->nullable()->after('availability');
            $table->unsignedInteger('away_queue_position')->nullable()->after('away_queue_type');
        });
    }

    public function down(): void
    {
        Schema::table('players', function (Blueprint $table) {
            $table->dropColumn(['availability', 'away_queue_type', 'away_queue_position']);
        });

        Schema::table('club_players', function (Blueprint $table) {
            $table->dropColumn(['is_guest', 'display_name']);
        });
    }
};
