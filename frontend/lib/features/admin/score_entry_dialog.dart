import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_responsive.dart';

class ScoreEntryDialog extends StatefulWidget {
  const ScoreEntryDialog({super.key, required this.match});

  final MatchInfo match;

  @override
  State<ScoreEntryDialog> createState() => _ScoreEntryDialogState();
}

class _ScoreEntryDialogState extends State<ScoreEntryDialog> {
  final _scoreAController = TextEditingController();
  final _scoreBController = TextEditingController();

  @override
  void dispose() {
    _scoreAController.dispose();
    _scoreBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter Match Score', style: RpcTypography.title(context)),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ScoreTeamColumn(
                        label: 'Team A',
                        teamName: widget.match.teamALabel,
                        controller: _scoreAController,
                        accentColor: c.primary,
                        autofocus: true,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: _VsDivider(),
                    ),
                    Expanded(
                      child: _ScoreTeamColumn(
                        label: 'Team B',
                        teamName: widget.match.teamBLabel,
                        controller: _scoreBController,
                        accentColor: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: RpcTypography.body(context)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(
                        'Submit',
                        style: RpcTypography.bodySemibold(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
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

  void _submit() {
    final scoreA = int.tryParse(_scoreAController.text);
    final scoreB = int.tryParse(_scoreBController.text);
    if (scoreA == null || scoreB == null) return;
    if (scoreA == scoreB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scores cannot be tied')),
      );
      return;
    }
    Navigator.pop(context, (scoreA, scoreB));
  }
}

class _VsDivider extends StatelessWidget {
  const _VsDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 1,
          height: 24,
          color: c.border,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('VS', style: RpcTypography.bodyBold(context)),
        ),
        Container(
          width: 1,
          height: 24,
          color: c.border,
        ),
      ],
    );
  }
}

class _ScoreTeamColumn extends StatelessWidget {
  const _ScoreTeamColumn({
    required this.label,
    required this.teamName,
    required this.controller,
    required this.accentColor,
    this.autofocus = false,
  });

  final String label;
  final String teamName;
  final TextEditingController controller;
  final Color accentColor;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: RpcTypography.bodyBold(context).copyWith(color: accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RpcTypography.bodySemibold(context),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: RpcTypography.bodyBold(context),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: RpcTypography.bodyMuted(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
