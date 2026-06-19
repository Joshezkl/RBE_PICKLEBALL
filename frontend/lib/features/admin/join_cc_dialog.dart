import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_responsive.dart';
import '../../core/widgets/rpc_status_badge.dart';

class JoinCcDialog extends StatefulWidget {
  const JoinCcDialog({
    super.key,
    required this.anchorPlayer,
    required this.eligiblePlayers,
  });

  final ChallengeCourtPlayer anchorPlayer;
  final List<ChallengeCourtPlayer> eligiblePlayers;

  static Future<ChallengeCourtPlayer?> show(
    BuildContext context, {
    required ChallengeCourtPlayer anchorPlayer,
    required List<ChallengeCourtPlayer> eligiblePlayers,
  }) {
    return showDialog<ChallengeCourtPlayer>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) => JoinCcDialog(
        anchorPlayer: anchorPlayer,
        eligiblePlayers: eligiblePlayers,
      ),
    );
  }

  @override
  State<JoinCcDialog> createState() => _JoinCcDialogState();
}

class _JoinCcDialogState extends State<JoinCcDialog> {
  final _searchController = TextEditingController();
  ChallengeCourtPlayer? _selectedPartner;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChallengeCourtPlayer> get _partnerOptions {
    final query = _searchController.text.trim().toLowerCase();
    return widget.eligiblePlayers
        .where((player) => player.id != widget.anchorPlayer.id)
        .where(
          (player) =>
              query.isEmpty || player.name.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final listHeight = RpcLayout.dialogContentHeight(
      context,
      fraction: 0.35,
      min: 200,
      max: 320,
    );

    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Challenge Court',
                style: RpcTypography.title(context),
              ),
              const SizedBox(height: RpcSpacing.md),
              Text(
                'Player: ${widget.anchorPlayer.name}',
                style: RpcTypography.bodySemibold(context),
              ),
              const SizedBox(height: RpcSpacing.xs),
              Text(
                'Select a partner for this team.',
                style: RpcTypography.bodyMuted(context),
              ),
              const SizedBox(height: RpcSpacing.md),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search partner',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: RpcSpacing.sm),
              SizedBox(
                height: listHeight,
                child: Material(
                  color: c.background.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                  child: _partnerOptions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(RpcSpacing.md),
                            child: Text(
                              'No eligible partners found',
                              style: RpcTypography.bodyMuted(context),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _partnerOptions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final player = _partnerOptions[index];
                            final selected =
                                _selectedPartner?.id == player.id;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              title: Text(player.name),
                              subtitle: Text(
                                '${player.wins}W / ${player.losses}L',
                                style: RpcTypography.caption(context),
                              ),
                              onTap: () =>
                                  setState(() => _selectedPartner = player),
                              trailing: selected
                                  ? Icon(Icons.check_circle, color: c.primary)
                                  : null,
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: RpcSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selectedPartner == null
                          ? null
                          : () => Navigator.pop(context, _selectedPartner),
                      child: const Text('Confirm team'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChallengeCourtBadge extends StatelessWidget {
  const ChallengeCourtBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const RpcStatusBadge(
      label: 'CC',
      tone: RpcBadgeTone.warning,
    );
  }
}
