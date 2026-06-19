<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tournaments', function (Blueprint $table) {
            $table->unsignedTinyInteger('group_count')->default(4)->after('advance_count');
        });

        Schema::table('tournament_teams', function (Blueprint $table) {
            $table->string('group_key', 4)->nullable()->after('tournament_category_id');
        });

        Schema::table('tournament_matches', function (Blueprint $table) {
            $table->string('group_key', 4)->nullable()->after('tournament_category_id');
        });
    }

    public function down(): void
    {
        Schema::table('tournament_matches', function (Blueprint $table) {
            $table->dropColumn('group_key');
        });

        Schema::table('tournament_teams', function (Blueprint $table) {
            $table->dropColumn('group_key');
        });

        Schema::table('tournaments', function (Blueprint $table) {
            $table->dropColumn('group_count');
        });
    }
};
