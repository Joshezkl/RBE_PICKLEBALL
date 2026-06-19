<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->string('gender', 10)->nullable()->after('skill_level');
        });
    }

    public function down(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->dropColumn('gender');
        });
    }
};
