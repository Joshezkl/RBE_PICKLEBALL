<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->string('skill_level', 20)->default('beginner')->after('name');
        });
    }

    public function down(): void
    {
        Schema::table('club_players', function (Blueprint $table) {
            $table->dropColumn('skill_level');
        });
    }
};
