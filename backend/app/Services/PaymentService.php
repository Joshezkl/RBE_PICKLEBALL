<?php

namespace App\Services;

use App\Models\ClubPlayer;
use App\Models\Payment;
use App\Models\PlaySession;
use App\Models\SessionPlayer;
use App\Support\PaymentStatus;
use Illuminate\Support\Facades\DB;

class PaymentService
{
    public function initialPaymentStatus(PlaySession $session): string
    {
        return $session->require_payment ? PaymentStatus::PENDING : PaymentStatus::FREE;
    }

    public function ensureRegistration(PlaySession $session, ClubPlayer $clubPlayer): SessionPlayer
    {
        $existing = SessionPlayer::query()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->first();

        if ($existing) {
            return $existing;
        }

        return SessionPlayer::query()->create([
            'play_session_id' => $session->id,
            'club_player_id' => $clubPlayer->id,
            'session_matches' => 0,
            'session_wins' => 0,
            'session_losses' => 0,
            'payment_status' => $this->initialPaymentStatus($session),
        ]);
    }

    public function markPaid(
        PlaySession $session,
        ClubPlayer $clubPlayer,
        string $method = Payment::METHOD_CASH,
        ?int $amountCents = null,
    ): SessionPlayer {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        $amount = $amountCents ?? (int) $session->session_fee_cents;

        return DB::transaction(function () use ($session, $clubPlayer, $method, $amount) {
            $sessionPlayer = $this->ensureRegistration($session, $clubPlayer);

            $sessionPlayer->update([
                'payment_status' => PaymentStatus::PAID,
                'payment_amount_cents' => $amount,
                'payment_method' => $method,
                'paid_at' => now(),
            ]);

            Payment::query()->create([
                'play_session_id' => $session->id,
                'club_player_id' => $clubPlayer->id,
                'session_player_id' => $sessionPlayer->id,
                'amount_cents' => $amount,
                'method' => $method,
                'status' => Payment::STATUS_COMPLETED,
                'recorded_at' => now(),
            ]);

            return $sessionPlayer->fresh();
        });
    }

    public function markWaived(PlaySession $session, ClubPlayer $clubPlayer, ?string $notes = null): SessionPlayer
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        return DB::transaction(function () use ($session, $clubPlayer, $notes) {
            $sessionPlayer = $this->ensureRegistration($session, $clubPlayer);

            $sessionPlayer->update([
                'payment_status' => PaymentStatus::WAIVED,
                'payment_amount_cents' => 0,
                'payment_method' => null,
                'paid_at' => now(),
            ]);

            Payment::query()->create([
                'play_session_id' => $session->id,
                'club_player_id' => $clubPlayer->id,
                'session_player_id' => $sessionPlayer->id,
                'amount_cents' => 0,
                'method' => Payment::METHOD_OTHER,
                'status' => Payment::STATUS_WAIVED,
                'recorded_at' => now(),
                'notes' => $notes,
            ]);

            return $sessionPlayer->fresh();
        });
    }

    public function applyPaymentAction(
        PlaySession $session,
        ClubPlayer $clubPlayer,
        ?string $paymentAction,
    ): SessionPlayer {
        $sessionPlayer = $this->ensureRegistration($session, $clubPlayer);

        if ($paymentAction === 'paid') {
            return $this->markPaid($session, $clubPlayer);
        }

        if ($paymentAction === 'waived') {
            return $this->markWaived($session, $clubPlayer);
        }

        if ($paymentAction === 'pending' && $session->require_payment) {
            $sessionPlayer->update(['payment_status' => PaymentStatus::PENDING]);

            return $sessionPlayer->fresh();
        }

        return $sessionPlayer;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function pendingForSession(PlaySession $session): array
    {
        return SessionPlayer::query()
            ->where('play_session_id', $session->id)
            ->where('payment_status', PaymentStatus::PENDING)
            ->with('clubPlayer')
            ->orderBy('created_at')
            ->get()
            ->map(fn (SessionPlayer $sp) => $this->formatPendingRegistration($sp))
            ->values()
            ->all();
    }

    public function formatPendingRegistration(SessionPlayer $sessionPlayer): array
    {
        $clubPlayer = $sessionPlayer->clubPlayer;

        return [
            'sessionPlayerId' => $sessionPlayer->id,
            'clubPlayerId' => $clubPlayer?->id,
            'name' => $clubPlayer?->publicName() ?? 'Unknown',
            'isGuest' => (bool) $clubPlayer?->is_guest,
            'registeredAt' => $sessionPlayer->created_at?->toIso8601String(),
        ];
    }

    public function formatRegistrationStatus(
        PlaySession $session,
        SessionPlayer $sessionPlayer,
        ?ClubPlayer $clubPlayer = null,
    ): array {
        $clubPlayer ??= $sessionPlayer->clubPlayer;

        return [
            'inSession' => false,
            'registered' => true,
            'status' => $sessionPlayer->payment_status === PaymentStatus::PENDING
                ? 'awaiting_payment'
                : 'registered',
            'message' => $sessionPlayer->payment_status === PaymentStatus::PENDING
                ? 'Pay at the registration desk to join the queue'
                : 'Registered — waiting to join queue',
            'clubPlayerId' => $clubPlayer?->id,
            'playerName' => $clubPlayer?->publicName(),
            'isGuest' => (bool) $clubPlayer?->is_guest,
            'paymentStatus' => $sessionPlayer->payment_status,
            'sessionFeeCents' => (int) $session->session_fee_cents,
            'requirePayment' => (bool) $session->require_payment,
        ];
    }
}
