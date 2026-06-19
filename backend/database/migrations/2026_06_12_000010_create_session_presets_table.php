<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('session_presets', function (Blueprint $table) {
            $table->id();
            $table->string('name', 120);
            $table->string('match_mode', 40);
            $table->string('play_format', 10)->default('doubles');
            $table->unsignedTinyInteger('court_count')->default(4);
            $table->boolean('auto_assign_enabled')->default(false);
            $table->json('match_mode_settings')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('session_presets');
    }
};
