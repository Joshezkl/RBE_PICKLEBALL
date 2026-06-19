<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->string('match_mode', 32)->default('auto_balanced')->after('play_format');
            $table->json('match_mode_settings')->nullable()->after('match_mode');
        });

        Schema::table('players', function (Blueprint $table) {
            $table->string('skill_level', 20)->nullable()->after('name');
            $table->string('gender', 10)->nullable()->after('skill_level');
        });

        Schema::table('courts', function (Blueprint $table) {
            $table->string('skill_bracket', 20)->nullable()->after('court_number');
        });

        $this->expandQueueTypeColumn();
    }

    public function down(): void
    {
        Schema::table('courts', function (Blueprint $table) {
            $table->dropColumn('skill_bracket');
        });

        Schema::table('players', function (Blueprint $table) {
            $table->dropColumn(['skill_level', 'gender']);
        });

        Schema::table('play_sessions', function (Blueprint $table) {
            $table->dropColumn(['match_mode', 'match_mode_settings']);
        });
    }

    private function expandQueueTypeColumn(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        DB::statement('ALTER TABLE queues MODIFY queue_type VARCHAR(32) NOT NULL');
    }
};
