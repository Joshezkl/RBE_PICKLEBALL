<?php

namespace App\Support;

abstract class PaymentStatus
{
    public const PENDING = 'pending';

    public const PAID = 'paid';

    public const WAIVED = 'waived';

    public const FREE = 'free';

    public const ALL = [
        self::PENDING,
        self::PAID,
        self::WAIVED,
        self::FREE,
    ];

    public static function canJoinQueue(string $status): bool
    {
        return in_array($status, [self::PAID, self::WAIVED, self::FREE], true);
    }
}
