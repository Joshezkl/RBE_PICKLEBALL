<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tournaments', function (Blueprint $table) {
            $table->string('registration_token', 64)->nullable()->unique()->after('status');
        });

        foreach (\App\Models\Tournament::query()->whereNull('registration_token')->cursor() as $tournament) {
            $tournament->update(['registration_token' => Str::random(32)]);
        }
    }

    public function down(): void
    {
        Schema::table('tournaments', function (Blueprint $table) {
            $table->dropColumn('registration_token');
        });
    }
};
