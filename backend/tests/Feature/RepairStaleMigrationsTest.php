<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class RepairStaleMigrationsTest extends TestCase
{
    use RefreshDatabase;

    public function test_repair_stale_marks_create_migration_when_table_exists(): void
    {
        Schema::dropIfExists('session_partner_pairs');
        Schema::create('session_partner_pairs', function ($table) {
            $table->id();
            $table->timestamps();
        });

        DB::table('migrations')
            ->where('migration', '2026_06_17_000001_create_session_partner_pairs_table')
            ->delete();

        Artisan::call('migrate:repair-stale');

        $this->assertDatabaseHas('migrations', [
            'migration' => '2026_06_17_000001_create_session_partner_pairs_table',
        ]);
    }

    public function test_migrate_succeeds_when_session_partner_pairs_already_exists(): void
    {
        Schema::dropIfExists('session_partner_pairs');
        Schema::create('session_partner_pairs', function ($table) {
            $table->id();
            $table->timestamps();
        });

        DB::table('migrations')
            ->where('migration', '2026_06_17_000001_create_session_partner_pairs_table')
            ->delete();

        Artisan::call('migrate', ['--force' => true]);

        $this->assertDatabaseHas('migrations', [
            'migration' => '2026_06_17_000001_create_session_partner_pairs_table',
        ]);
    }
}
