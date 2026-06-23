<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Database\Migrations\Migrator;
use Illuminate\Support\Facades\Schema;

class RepairStaleMigrationsCommand extends Command
{
    protected $signature = 'migrate:repair-stale';

    protected $description = 'Mark pending migrations as run when their schema changes already exist';

    public function handle(Migrator $migrator): int
    {
        if (! $migrator->repositoryExists()) {
            $migrator->getRepository()->createRepository();
        }

        $repository = $migrator->getRepository();
        $files = $migrator->getMigrationFiles(database_path('migrations'));
        $ran = $repository->getRan();
        $batch = $repository->getNextBatchNumber();
        $repaired = 0;

        foreach ($files as $name => $path) {
            if (in_array($name, $ran, true)) {
                continue;
            }

            if (! $this->schemaAlreadyApplied((string) $path)) {
                continue;
            }

            $repository->log($name, $batch);
            $this->line("Marked migrated: {$name}");
            $repaired++;
        }

        $this->info("Repaired {$repaired} migration record(s).");

        return self::SUCCESS;
    }

    private function schemaAlreadyApplied(string $path): bool
    {
        $content = file_get_contents($path);
        if ($content === false) {
            return false;
        }

        if (preg_match_all("/Schema::create\(\s*'([^']+)'/", $content, $tables) && $tables[1] !== []) {
            foreach ($tables[1] as $table) {
                if (! Schema::hasTable($table)) {
                    return false;
                }
            }

            return true;
        }

        if (str_contains($content, '->change()')) {
            return false;
        }

        if (preg_match("/Schema::table\(\s*'([^']+)'/", $content, $tableMatch)) {
            $table = $tableMatch[1];
            if (! Schema::hasTable($table)) {
                return false;
            }

            if (! preg_match_all(
                '/\$table->(?:foreignId|unsignedTinyInteger|string|integer|boolean|text|json|timestamp|foreign)\(\s*\'([^\']+)\'/',
                $content,
                $columns
            ) || $columns[1] === []) {
                return false;
            }

            foreach ($columns[1] as $column) {
                if (! Schema::hasColumn($table, $column)) {
                    return false;
                }
            }

            return true;
        }

        return false;
    }
}
