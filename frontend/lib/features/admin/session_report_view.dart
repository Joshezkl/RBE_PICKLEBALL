import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_kpi_card.dart';
import '../../core/widgets/rpc_kpi_row.dart';
import '../../core/widgets/rpc_section_header.dart';

class SessionReportView extends StatelessWidget {
  const SessionReportView({super.key, required this.report});

  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RpcSectionHeader(
            title: 'Session Report',
            subtitle: report.sessionName,
          ),
          const SizedBox(height: RpcSpacing.lg),
          RpcKpiRow(
            cards: [
              RpcKpiCard(
                label: 'Matches',
                value: '${report.totalMatches}',
                icon: Icons.sports_tennis_rounded,
                iconColor: c.primary,
              ),
              RpcKpiCard(
                label: 'Session Duration',
                value: '${report.durationMinutes} min',
                icon: Icons.schedule_rounded,
                iconColor: c.accentPurple,
              ),
              RpcKpiCard(
                label: 'Avg Match',
                value: report.avgMatchDurationMinutes > 0
                    ? '${report.avgMatchDurationMinutes} min'
                    : '—',
                icon: Icons.timer_outlined,
                iconColor: c.primary,
              ),
              RpcKpiCard(
                label: 'Utilization',
                value: '${report.courtUtilizationPercent}%',
                icon: Icons.pie_chart_outline_rounded,
                iconColor: c.accentOrange,
              ),
              RpcKpiCard(
                label: 'Winners / Losers',
                value: '${report.winnersQueueSize} / ${report.losersQueueSize}',
                icon: Icons.groups_outlined,
                iconColor: c.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const RpcSectionHeader(title: 'Player Summary'),
          const SizedBox(height: 12),
          if (report.playerSummaries.isEmpty)
            Text(
              'No players',
              style: RpcTypography.bodyMuted(context),
            )
          else
            ...report.playerSummaries.map(
              (player) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        player['name'] as String? ?? '',
                        style: RpcTypography.body(context),
                      ),
                    ),
                    Text(
                      '${player['wins']}W / ${player['losses']}L',
                      style: RpcTypography.bodySmallMuted(context),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
