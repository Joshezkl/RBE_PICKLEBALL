import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/collapsible_section.dart';
import '../../core/widgets/rpc_status_badge.dart';

String formatPesos(int cents) => '₱${(cents / 100).toStringAsFixed(0)}';

class PendingPaymentsPanel extends StatelessWidget {
  const PendingPaymentsPanel({
    super.key,
    required this.state,
    required this.api,
    required this.sessionController,
    this.compact = false,
  });

  final SessionState state;
  final ApiClient api;
  final SessionController sessionController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pending = state.pendingPayments;
    if (pending.isEmpty) return const SizedBox.shrink();

    final feeLabel = state.session.requirePayment
        ? formatPesos(state.session.sessionFeeCents)
        : null;

    return CollapsibleSection(
      title: 'Awaiting Payment',
      showSideline: true,
      subtitle: feeLabel != null
          ? '${pending.length} player(s) · $feeLabel each'
          : '${pending.length} player(s)',
      initiallyExpanded: true,
      child: Column(
        children: pending.map((entry) {
          return _PendingRow(
            entry: entry,
            feeCents: state.session.sessionFeeCents,
            compact: compact,
            onPaid: () => _markPaid(context, entry),
            onWaived: () => _markWaived(context, entry),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, PendingPayment entry) async {
    try {
      final fresh = await api.markRegistrationPaid(
        state.session.id,
        entry.clubPlayerId,
      );
      sessionController.applyState(fresh);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark paid: $e')),
        );
      }
    }
  }

  Future<void> _markWaived(BuildContext context, PendingPayment entry) async {
    try {
      final fresh = await api.markRegistrationWaived(
        state.session.id,
        entry.clubPlayerId,
      );
      sessionController.applyState(fresh);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not waive: $e')),
        );
      }
    }
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.entry,
    required this.feeCents,
    required this.onPaid,
    required this.onWaived,
    this.compact = false,
  });

  final PendingPayment entry;
  final int feeCents;
  final VoidCallback onPaid;
  final VoidCallback onWaived;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Padding(
      padding: const EdgeInsets.only(bottom: RpcSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: RpcTypography.bodySemibold(context),
                      ),
                    ),
                    if (entry.isGuest)
                      const RpcStatusBadge(
                        label: 'Guest',
                        tone: RpcBadgeTone.neutral,
                      ),
                  ],
                ),
                if (!compact)
                  Text(
                    formatPesos(feeCents),
                    style: RpcTypography.bodySmallMuted(context),
                  ),
              ],
            ),
          ),
          const SizedBox(width: RpcSpacing.sm),
          TextButton(
            onPressed: onWaived,
            child: Text('Waive', style: TextStyle(color: c.textMuted)),
          ),
          FilledButton(
            onPressed: onPaid,
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
  }
}
