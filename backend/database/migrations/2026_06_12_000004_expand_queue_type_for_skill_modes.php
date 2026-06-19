<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            return;
        }

        Schema::disableForeignKeyConstraints();

        Schema::create('queues_expanded', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('player_id')->constrained('players')->cascadeOnDelete();
            $table->string('queue_type', 32);
            $table->unsignedInteger('position');
            $table->timestamps();

            $table->unique(['play_session_id', 'player_id']);
            $table->index(['play_session_id', 'queue_type', 'position']);
        });

        DB::statement(
            'INSERT INTO queues_expanded (id, play_session_id, player_id, queue_type, position, created_at, updated_at)
             SELECT id, play_session_id, player_id, queue_type, position, created_at, updated_at FROM queues'
        );

        Schema::drop('queues');
        Schema::rename('queues_expanded', 'queues');

        Schema::enableForeignKeyConstraints();
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            return;
        }

        Schema::disableForeignKeyConstraints();

        Schema::create('queues_legacy', function (Blueprint $table) {
            $table->id();
            $table->foreignId('play_session_id')->constrained('play_sessions')->cascadeOnDelete();
            $table->foreignId('player_id')->constrained('players')->cascadeOnDelete();
            $table->enum('queue_type', ['winner', 'loser']);
            $table->unsignedInteger('position');
            $table->timestamps();

            $table->unique(['play_session_id', 'player_id']);
            $table->index(['play_session_id', 'queue_type', 'position']);
        });

        DB::statement(
            "INSERT INTO queues_legacy (id, play_session_id, player_id, queue_type, position, created_at, updated_at)
             SELECT id, play_session_id, player_id, queue_type, position, created_at, updated_at
             FROM queues
             WHERE queue_type IN ('winner', 'loser')"
        );

        Schema::drop('queues');
        Schema::rename('queues_legacy', 'queues');

        Schema::enableForeignKeyConstraints();
    }
};
