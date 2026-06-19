import 'package:flutter/material.dart';

import '../theme/rpc_spacing.dart';
import 'rpc_kpi_card.dart';

class RpcKpiRow extends StatelessWidget {
  const RpcKpiRow({
    super.key,
    required this.cards,
    this.compact = false,
  });

  final List<RpcKpiCard> cards;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = cards.length;
        final columns = constraints.maxWidth >= RpcBreakpoints.wide
            ? count.clamp(1, 4)
            : constraints.maxWidth >= RpcBreakpoints.compact
                ? 2
                : 1;

        final gap = compact ? RpcSpacing.sm : RpcSpacing.md;

        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                cards[i],
              ],
            ],
          );
        }

        final rowCount = (cards.length / columns).ceil();
        return Column(
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: gap),
                    Expanded(
                      child: row * columns + col < cards.length
                          ? cards[row * columns + col]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
