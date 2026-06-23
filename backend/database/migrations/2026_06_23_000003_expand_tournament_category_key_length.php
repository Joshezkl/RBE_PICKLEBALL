<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('tournament_categories')) {
            return;
        }

        if (! Schema::hasColumn('tournament_categories', 'category_key')) {
            return;
        }

        Schema::table('tournament_categories', function (Blueprint $table) {
            $table->string('category_key', 96)->change();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('tournament_categories')) {
            return;
        }

        if (! Schema::hasColumn('tournament_categories', 'category_key')) {
            return;
        }

        Schema::table('tournament_categories', function (Blueprint $table) {
            $table->string('category_key', 32)->change();
        });
    }
};
