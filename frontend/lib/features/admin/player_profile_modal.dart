import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/leaderboard_view.dart';
import '../../core/widgets/rpc_responsive.dart';
import '../../core/widgets/rpc_status_badge.dart';

class PlayerProfileModal extends StatefulWidget {
  const PlayerProfileModal({
    super.key,
    required this.player,
    required this.api,
    this.onDelete,
  });

  final ClubPlayerInfo player;
  final ApiClient api;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required ClubPlayerInfo player,
    required ApiClient api,
    VoidCallback? onDelete,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PlayerProfileModal(
        player: player,
        api: api,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<PlayerProfileModal> createState() => _PlayerProfileModalState();
}

class _PlayerProfileModalState extends State<PlayerProfileModal>
    with SingleTickerProviderStateMixin {
  PlayerProfileDetail? _profile;
  bool _loading = true;
  String? _error;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.api.getPlayerProfile(widget.player.id);
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return AlertDialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      title: Text(widget.player.name, style: RpcTypography.title(context)),
      content: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Text(_error!, style: RpcTypography.body(context))
                  : profile == null
                      ? Text(
                          'Profile unavailable',
                          style: RpcTypography.bodyMuted(context),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TabBar(
                              controller: _tabController,
                              isScrollable: context.isCompact,
                              tabs: const [
                                Tab(text: 'Overview'),
                                Tab(text: 'Sessions'),
                                Tab(text: 'Partners'),
                              ],
                            ),
                            const SizedBox(height: RpcSpacing.md),
                            SizedBox(
                              height: RpcLayout.dialogContentHeight(context),
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  SingleChildScrollView(
                                    child: _OverviewTab(profile: profile),
                                  ),
                                  SingleChildScrollView(
                                    child: profile.sessionHistory.isEmpty
                                        ? Text(
                                            'No session history yet',
                                            style: RpcTypography.bodyMuted(
                                              context,
                                            ),
                                          )
                                        : _SessionHistorySection(
                                            sessions: profile.sessionHistory,
                                          ),
                                  ),
                                  SingleChildScrollView(
                                    child: profile.bestPartners.isEmpty
                                        ? Text(
                                            'No partner data yet',
                                            style: RpcTypography.bodyMuted(
                                              context,
                                            ),
                                          )
                                        : _BestPartnersSection(
                                            partners: profile.bestPartners,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete!();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.rpc.danger,
            ),
            child: const Text('Delete Player'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile});

  final PlayerProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AllTimeSection(profile: profile),
        if (profile.preferredModeLabel != null) ...[
          const SizedBox(height: RpcSpacing.lg),
          _PreferredModeSection(profile: profile),
        ],
        if (profile.winRateTrend.isNotEmpty) ...[
          const SizedBox(height: RpcSpacing.lg),
          _WinRateTrendSection(trend: profile.winRateTrend),
        ],
        if (profile.inCurrentSession) ...[
          const SizedBox(height: RpcSpacing.lg),
          _CurrentSessionSection(profile: profile),
        ],
      ],
    );
  }
}

class _AllTimeSection extends StatelessWidget {
  const _AllTimeSection({required this.profile});

  final PlayerProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All-Time Stats', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        _StatRow(
          label: 'Skill Level',
          value: MatchModes.skillLabel(profile.skillLevel),
        ),
        _StatRow(
          label: 'Gender',
          value: MatchModes.genderLabel(profile.gender),
        ),
        _StatRow(label: 'Matches', value: '${profile.totalMatches}'),
        _StatRow(label: 'Wins', value: '${profile.totalWins}'),
        _StatRow(label: 'Losses', value: '${profile.totalLosses}'),
        _StatRow(
          label: 'Win Rate',
          value: '${profile.winRate.toStringAsFixed(1)}%',
        ),
        _StatRow(
          label: 'Point Differential',
          value: formatPointDifferential(profile.pointDifferential),
        ),
        _StatRow(
          label: 'Avg Margin',
          value: profile.avgMargin >= 0
              ? '+${profile.avgMargin.toStringAsFixed(1)}'
              : profile.avgMargin.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _PreferredModeSection extends StatelessWidget {
  const _PreferredModeSection({required this.profile});

  final PlayerProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferred Mode', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        RpcStatusBadge(
          label: profile.preferredModeLabel!,
          tone: RpcBadgeTone.primary,
        ),
      ],
    );
  }
}

class _WinRateTrendSection extends StatelessWidget {
  const _WinRateTrendSection({required this.trend});

  final List<PlayerProfileTrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Win Rate Trend', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _WinRateTrendPainter(
              trend: trend,
              lineColor: c.primary,
              fillColor: c.primary.withValues(alpha: 0.12),
              gridColor: c.border,
              labelStyle: RpcTypography.caption(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _WinRateTrendPainter extends CustomPainter {
  _WinRateTrendPainter({
    required this.trend,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<PlayerProfileTrendPoint> trend;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    const bottomPad = 22.0;
    const sidePad = 8.0;
    final chartHeight = size.height - bottomPad;
    final chartWidth = size.width - sidePad * 2;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (var i = 0; i < trend.length; i++) {
      final x = sidePad + (chartWidth * i / (trend.length - 1).clamp(1, 999));
      final y = chartHeight - (trend[i].winRate / 100) * chartHeight;
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final fillPath = Path()..moveTo(points.first.dx, chartHeight);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath
        ..lineTo(points.last.dx, chartHeight)
        ..close();
      canvas.drawPath(fillPath, Paint()..color = fillColor);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 4, Paint()..color = lineColor);
    } else {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
      for (final point in points) {
        canvas.drawCircle(point, 3, Paint()..color = lineColor);
      }
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < trend.length; i++) {
      final label = trend[i].date ?? '${i + 1}';
      textPainter
        ..text = TextSpan(text: label, style: labelStyle)
        ..layout(maxWidth: 48);
      final x = (points[i].dx - textPainter.width / 2)
          .clamp(0.0, size.width - textPainter.width);
      textPainter.paint(canvas, Offset(x, size.height - bottomPad + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _WinRateTrendPainter oldDelegate) {
    return oldDelegate.trend != trend;
  }
}

class _BestPartnersSection extends StatelessWidget {
  const _BestPartnersSection({required this.partners});

  final List<PlayerProfilePartner> partners;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Best Partners', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        ...partners.map(
          (partner) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    partner.name,
                    style: RpcTypography.body(context),
                  ),
                ),
                Text(
                  '${partner.winsTogether}W / ${partner.matchesTogether}M',
                  style: RpcTypography.bodySmallMuted(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionHistorySection extends StatelessWidget {
  const _SessionHistorySection({required this.sessions});

  final List<PlayerProfileSession> sessions;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session History', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        ...sessions.take(8).map(
          (session) => Container(
            margin: const EdgeInsets.only(bottom: RpcSpacing.sm),
            padding: const EdgeInsets.all(RpcSpacing.sm),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.sessionName, style: RpcTypography.bodySemibold(context)),
                const SizedBox(height: 2),
                Text(
                  '${session.matchModeLabel} · ${session.wins}W ${session.losses}L · ${session.winRate.toStringAsFixed(0)}% · PD ${formatPointDifferential(session.pointDifferential)}',
                  style: RpcTypography.bodySmallMuted(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentSessionSection extends StatelessWidget {
  const _CurrentSessionSection({required this.profile});

  final PlayerProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Session', style: RpcTypography.bodySemibold(context)),
        const SizedBox(height: RpcSpacing.sm),
        _StatRow(label: 'Matches', value: '${profile.sessionMatches}'),
        _StatRow(label: 'Wins', value: '${profile.sessionWins}'),
        _StatRow(label: 'Losses', value: '${profile.sessionLosses}'),
        _StatRow(
          label: 'Win Rate',
          value: '${profile.sessionWinRate.toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: RpcTypography.body(context).copyWith(color: c.textMuted),
          ),
          Text(value, style: RpcTypography.bodySemibold(context)),
        ],
      ),
    );
  }
}
