<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->string('check_in_token', 64)->nullable()->unique()->after('status');
        });

        foreach (\App\Models\PlaySession::query()->where('status', 'active')->get() as $session) {
            $session->update(['check_in_token' => Str::random(32)]);
        }
    }

    public function down(): void
    {
        Schema::table('play_sessions', function (Blueprint $table) {
            $table->dropColumn('check_in_token');
        });
    }
};
