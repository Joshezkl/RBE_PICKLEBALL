<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('session.{sessionId}', fn () => true);
