<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function regularCourtId(array $state): int
    {
        $court = collect($state['courts'])
            ->first(fn (array $item) => ! ($item['isChallengeCourt'] ?? false));

        $this->assertNotNull($court, 'Expected a non-challenge court in session state');

        return $court['id'];
    }
}
