<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->boolean('auto_assign_enabled')->default(false)->after('court_count');
        });
    }

    public function down(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->dropColumn('auto_assign_enabled');
        });
    }
};
