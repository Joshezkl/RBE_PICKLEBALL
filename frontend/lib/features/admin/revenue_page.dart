import 'package:flutter/material.dart';

import '../../core/decor/rpc_decor_empty_state.dart';
import '../../core/admin_nav.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/rpc_kpi_card.dart';
import '../../core/widgets/rpc_kpi_row.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;
import 'pending_payments_panel.dart' show formatPesos;

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key, this.adminPin});

  final String? adminPin;

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  late final ApiClient _api;
  RevenueSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pin = widget.adminPin ?? rpcAdminPinController.pin;
    _api = ApiClient(adminPin: pin);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _api.getRevenue();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return RpcShell(
      activeDestination: RpcNavDestination.revenue,
      pageTitle: 'Revenue',
      pageSubtitle: 'Session payments and collections · export from History',
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      navDestinations: adminNavDestinations,
      loading: _loading && summary == null,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            RpcErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          if (summary != null) ...[
            RpcKpiRow(
              compact: true,
              cards: [
                RpcKpiCard(
                  label: 'Total Revenue',
                  value: formatPesos(summary.totalRevenueCents),
                  icon: Icons.payments_outlined,
                ),
                RpcKpiCard(
                  label: 'Payments',
                  value: '${summary.completedCount}',
                  icon: Icons.receipt_long_outlined,
                ),
                RpcKpiCard(
                  label: 'Waived',
                  value: '${summary.waivedCount}',
                  icon: Icons.volunteer_activism_outlined,
                ),
              ],
            ),
            const SizedBox(height: RpcSpacing.lg),
            if (summary.bySession.isNotEmpty) ...[
              Text('By session', style: RpcTypography.title(context)),
              const SizedBox(height: RpcSpacing.sm),
              RpcCard(
                child: Column(
                  children: summary.bySession.map((row) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.sessionName ?? 'Session ${row.sessionId}'),
                      trailing: Text(
                        '${formatPesos(row.totalCents)} · ${row.count}',
                        style: RpcTypography.bodySemibold(context),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: RpcSpacing.lg),
            ],
            Text('Recent payments', style: RpcTypography.title(context)),
            const SizedBox(height: RpcSpacing.sm),
            RpcCard(
              child: summary.recent.isEmpty
                  ? const RpcDecorEmptyState(
                      title: 'No payments recorded yet',
                      subtitle: 'Payments appear here when players are marked paid',
                      icon: Icons.receipt_long_outlined,
                      compact: true,
                    )
                  : Column(
                      children: summary.recent.take(20).map((row) {
                        final c = context.rpc;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.playerName ?? 'Player ${row.clubPlayerId}'),
                          subtitle: Text(
                            row.sessionName ?? 'Session ${row.sessionId}',
                            style: RpcTypography.bodySmallMuted(context),
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                row.status == 'waived'
                                    ? 'Waived'
                                    : formatPesos(row.amountCents),
                                style: RpcTypography.bodySemibold(context),
                              ),
                              Text(
                                row.method,
                                style: RpcTypography.caption(context).copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
