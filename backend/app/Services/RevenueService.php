<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\PlaySession;
use App\Models\SessionPlayer;
use App\Support\PaymentStatus;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class RevenueService
{
    /**
     * @return array<string, mixed>
     */
    public function summary(?string $from = null, ?string $to = null, ?int $sessionId = null): array
    {
        $query = Payment::query()->with(['clubPlayer', 'playSession']);

        if ($from !== null) {
            $query->where('recorded_at', '>=', Carbon::parse($from)->startOfDay());
        }

        if ($to !== null) {
            $query->where('recorded_at', '<=', Carbon::parse($to)->endOfDay());
        }

        if ($sessionId !== null) {
            $query->where('play_session_id', $sessionId);
        }

        $payments = $query->orderByDesc('recorded_at')->get();

        $completed = $payments->where('status', Payment::STATUS_COMPLETED);
        $waived = $payments->where('status', Payment::STATUS_WAIVED);

        return [
            'from' => $from,
            'to' => $to,
            'sessionId' => $sessionId,
            'totalRevenueCents' => (int) $completed->sum('amount_cents'),
            'completedCount' => $completed->count(),
            'waivedCount' => $waived->count(),
            'paymentCount' => $payments->count(),
            'byMethod' => $this->groupByMethod($completed),
            'bySession' => $this->groupBySession($completed),
            'recent' => $payments->take(50)->map(fn (Payment $p) => $this->formatPayment($p))->values()->all(),
        ];
    }

    public function toCsv(?string $from = null, ?string $to = null, ?int $sessionId = null): string
    {
        $query = Payment::query()->with(['clubPlayer', 'playSession']);

        if ($from !== null) {
            $query->where('recorded_at', '>=', Carbon::parse($from)->startOfDay());
        }

        if ($to !== null) {
            $query->where('recorded_at', '<=', Carbon::parse($to)->endOfDay());
        }

        if ($sessionId !== null) {
            $query->where('play_session_id', $sessionId);
        }

        $payments = $query->orderBy('recorded_at')->get();

        $lines = [
            'recorded_at,session_id,session_name,club_player_id,player_name,amount_cents,method,status,notes',
        ];

        foreach ($payments as $payment) {
            $lines[] = implode(',', [
                $payment->recorded_at?->toIso8601String() ?? '',
                $payment->play_session_id,
                $this->csvEscape($payment->playSession?->name ?? ''),
                $payment->club_player_id,
                $this->csvEscape($payment->clubPlayer?->publicName() ?? ''),
                $payment->amount_cents,
                $payment->method,
                $payment->status,
                $this->csvEscape($payment->notes ?? ''),
            ]);
        }

        return implode("\n", $lines);
    }

    /**
     * Revenue section appended to per-session history exports.
     *
     * @return list<string>
     */
    public function sessionReportLines(PlaySession $session): array
    {
        $summary = $this->summary(sessionId: $session->id);
        $payments = Payment::query()
            ->with('clubPlayer')
            ->where('play_session_id', $session->id)
            ->orderBy('recorded_at')
            ->get();

        $pending = SessionPlayer::query()
            ->with('clubPlayer')
            ->where('play_session_id', $session->id)
            ->where('payment_status', PaymentStatus::PENDING)
            ->orderBy('created_at')
            ->get();

        $lines = [];
        $lines[] = '';
        $lines[] = $this->csvRow(['Revenue Summary']);
        $lines[] = $this->csvRow(['Payment Required', $session->require_payment ? 'Yes' : 'No']);
        $lines[] = $this->csvRow(['Session Fee (PHP)', number_format($session->session_fee_cents / 100, 2)]);
        $lines[] = $this->csvRow(['Total Collected (PHP)', number_format($summary['totalRevenueCents'] / 100, 2)]);
        $lines[] = $this->csvRow(['Completed Payments', $summary['completedCount']]);
        $lines[] = $this->csvRow(['Waived', $summary['waivedCount']]);
        $lines[] = $this->csvRow(['Still Pending', $pending->count()]);
        $lines[] = '';

        if ($payments->isNotEmpty()) {
            $lines[] = $this->csvRow(['Payment Transactions']);
            $lines[] = $this->csvRow([
                'Recorded At', 'Player', 'Amount (PHP)', 'Method', 'Status', 'Notes',
            ]);
            foreach ($payments as $payment) {
                $lines[] = $this->csvRow([
                    $payment->recorded_at?->toIso8601String() ?? '',
                    $payment->clubPlayer?->publicName() ?? '',
                    number_format($payment->amount_cents / 100, 2),
                    $payment->method,
                    $payment->status,
                    $payment->notes ?? '',
                ]);
            }
            $lines[] = '';
        }

        if ($pending->isNotEmpty()) {
            $lines[] = $this->csvRow(['Awaiting Payment']);
            $lines[] = $this->csvRow(['Player', 'Registered At']);
            foreach ($pending as $registration) {
                $lines[] = $this->csvRow([
                    $registration->clubPlayer?->publicName() ?? '',
                    $registration->created_at?->toIso8601String() ?? '',
                ]);
            }
        }

        return $lines;
    }

    /**
     * @param  list<mixed>  $fields
     */
    private function csvRow(array $fields): string
    {
        return implode(',', array_map(
            fn ($value) => $this->csvEscape((string) $value),
            $fields,
        ));
    }

    /**
     * @param  Collection<int, Payment>  $payments
     * @return list<array<string, mixed>>
     */
    private function groupByMethod(Collection $payments): array
    {
        return $payments
            ->groupBy('method')
            ->map(fn (Collection $group, string $method) => [
                'method' => $method,
                'count' => $group->count(),
                'totalCents' => (int) $group->sum('amount_cents'),
            ])
            ->values()
            ->all();
    }

    /**
     * @param  Collection<int, Payment>  $payments
     * @return list<array<string, mixed>>
     */
    private function groupBySession(Collection $payments): array
    {
        return $payments
            ->groupBy('play_session_id')
            ->map(fn (Collection $group) => [
                'sessionId' => $group->first()->play_session_id,
                'sessionName' => $group->first()->playSession?->name,
                'count' => $group->count(),
                'totalCents' => (int) $group->sum('amount_cents'),
            ])
            ->values()
            ->all();
    }

    private function formatPayment(Payment $payment): array
    {
        return [
            'id' => $payment->id,
            'sessionId' => $payment->play_session_id,
            'sessionName' => $payment->playSession?->name,
            'clubPlayerId' => $payment->club_player_id,
            'playerName' => $payment->clubPlayer?->publicName(),
            'amountCents' => $payment->amount_cents,
            'method' => $payment->method,
            'status' => $payment->status,
            'recordedAt' => $payment->recorded_at?->toIso8601String(),
            'notes' => $payment->notes,
        ];
    }

    private function csvEscape(string $value): string
    {
        if (str_contains($value, ',') || str_contains($value, '"') || str_contains($value, "\n")) {
            return '"'.str_replace('"', '""', $value).'"';
        }

        return $value;
    }
}
