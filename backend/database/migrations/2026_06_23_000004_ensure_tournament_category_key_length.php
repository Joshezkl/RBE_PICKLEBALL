<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Safety net for deployments where the previous alter migration was
     * marked as run without actually widening category_key.
     */
    public function up(): void
    {
        if (! Schema::hasTable('tournament_categories')) {
            return;
        }

        if (! Schema::hasColumn('tournament_categories', 'category_key')) {
            return;
        }

        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        $column = DB::selectOne(
            'SELECT CHARACTER_MAXIMUM_LENGTH AS max_length
             FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = ?
               AND COLUMN_NAME = ?',
            ['tournament_categories', 'category_key'],
        );

        $currentLength = (int) ($column->max_length ?? 0);
        if ($currentLength >= 96) {
            return;
        }

        DB::statement(
            'ALTER TABLE tournament_categories MODIFY category_key VARCHAR(96) NOT NULL'
        );
    }

    public function down(): void
    {
        // No-op: handled by 2026_06_23_000003 down().
    }
};
