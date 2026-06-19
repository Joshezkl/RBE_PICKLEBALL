<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('challenge_court_teams', function (Blueprint $table) {
            $table->unsignedTinyInteger('cc_wins')->default(0)->after('status');
            $table->foreignId('court_id')
                ->nullable()
                ->after('cc_wins')
                ->constrained('courts')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('challenge_court_teams', function (Blueprint $table) {
            $table->dropConstrainedForeignId('court_id');
            $table->dropColumn('cc_wins');
        });
    }
};
