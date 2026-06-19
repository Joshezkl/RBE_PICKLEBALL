import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/file_download.dart';
import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/admin_nav.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/rpc_section_header.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;
import 'session_history_detail_view.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.adminPin});

  final String? adminPin;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final ApiClient _api;
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  Map<String, int> _markers = {};
  List<SessionHistorySummary> _daySessions = [];
  SessionHistoryDetail? _selectedDetail;
  int? _selectedSessionId;

  bool _loadingMonth = false;
  bool _loadingDay = false;
  bool _loadingDetail = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
    );
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadMonth();
    _loadDay(_selectedDate);
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loadingMonth = true;
      _error = null;
    });
    try {
      final markers = await _api.getCalendarMarkers(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );
      setState(() => _markers = markers);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingMonth = false);
    }
  }

  Future<void> _loadDay(DateTime date) async {
    setState(() {
      _loadingDay = true;
      _error = null;
      _selectedDetail = null;
      _selectedSessionId = null;
    });
    try {
      final sessions = await _api.getSessionsOnDate(_formatDateKey(date));
      setState(() => _daySessions = sessions);
      if (sessions.isNotEmpty) {
        await _loadSessionDetail(sessions.first.id);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingDay = false);
    }
  }

  Future<void> _loadSessionDetail(int sessionId) async {
    setState(() {
      _loadingDetail = true;
      _selectedSessionId = sessionId;
      _error = null;
    });
    try {
      final detail = await _api.getSessionHistory(sessionId);
      setState(() => _selectedDetail = detail);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingDetail = false);
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadDay(date);
  }

  Future<void> _exportSelectedSession() async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) return;

    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final report = await _api.exportSessionReport(sessionId);
      downloadTextFile(
        filename: report.filename,
        content: report.content,
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      );
    });
    _loadMonth();
  }

  void _goToToday() {
    final now = DateTime.now();
    if (_visibleMonth.year != now.year || _visibleMonth.month != now.month) {
      setState(() => _visibleMonth = DateTime(now.year, now.month));
      _loadMonth();
    }
    _selectDate(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final monthTotal = _markers.values.fold<int>(0, (sum, count) => sum + count);

    return RpcShell(
      activeDestination: RpcNavDestination.history,
      pageTitle: 'History',
      pageSubtitle: monthTotal > 0
          ? '${_monthLabel(_visibleMonth.month)} ${_visibleMonth.year} · $monthTotal session${monthTotal == 1 ? '' : 's'}'
          : 'Browse past sessions by date',
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      navDestinations: adminNavDestinations,
      maxWidth: 1200,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.md),
              child: RpcErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= RpcBreakpoints.medium;
              final calendar = _CalendarPanel(
                visibleMonth: _visibleMonth,
                selectedDate: _selectedDate,
                markers: _markers,
                loading: _loadingMonth,
                onPreviousMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
                onDateSelected: _selectDate,
                onToday: _goToToday,
              );
              final details = _HistoryPanel(
                selectedDate: _selectedDate,
                sessions: _daySessions,
                selectedSessionId: _selectedSessionId,
                detail: _selectedDetail,
                loadingDay: _loadingDay,
                loadingDetail: _loadingDetail,
                exporting: _exporting,
                onSessionSelected: _loadSessionDetail,
                onExport: _selectedSessionId == null ? null : _exportSelectedSession,
              );

              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: calendar),
                    const SizedBox(width: RpcSpacing.md),
                    Expanded(flex: 3, child: details),
                  ],
                );
              }

              return Column(
                children: [
                  calendar,
                  const SizedBox(height: RpcSpacing.md),
                  details,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthLabel(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  String _formatDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.visibleMonth,
    required this.selectedDate,
    required this.markers,
    required this.loading,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
    required this.onToday,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<String, int> markers;
  final bool loading;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();

    return RpcCard(
      padding: const EdgeInsets.all(RpcSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              Expanded(
                child: Text(
                  '${_monthLabel(visibleMonth.month)} ${visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: RpcTypography.bodySemibold(context),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Today'),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: RpcSpacing.sm),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: RpcTypography.caption(context),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: RpcSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((startWeekday + daysInMonth + 6) ~/ 7) * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                dayNumber,
              );
              final key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final count = markers[key] ?? 0;
              final isSelected = DateUtils.isSameDay(date, selectedDate);
              final isToday = DateUtils.isSameDay(date, today);

              return _DayCell(
                day: dayNumber,
                sessionCount: count,
                isSelected: isSelected,
                isToday: isToday,
                onTap: () => onDateSelected(date),
              );
            },
          ),
          const SizedBox(height: RpcSpacing.xs),
          Text(
            'Filled dots mark days with sessions.',
            style: RpcTypography.caption(context),
          ),
        ],
      ),
    );
  }

  String _monthLabel(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.sessionCount,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final int sessionCount;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Material(
      color: isSelected
          ? c.primaryLight
          : isToday
              ? c.background
              : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? c.primary
                  : isToday
                      ? c.primary.withValues(alpha: 0.35)
                      : c.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: RpcTypography.caption(context).copyWith(
                  color: isSelected ? c.primary : c.text,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              if (sessionCount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    sessionCount.clamp(1, 3),
                    (i) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.selectedDate,
    required this.sessions,
    required this.selectedSessionId,
    required this.detail,
    required this.loadingDay,
    required this.loadingDetail,
    required this.onSessionSelected,
    this.onExport,
    this.exporting = false,
  });

  final DateTime selectedDate;
  final List<SessionHistorySummary> sessions;
  final int? selectedSessionId;
  final SessionHistoryDetail? detail;
  final bool loadingDay;
  final bool loadingDetail;
  final bool exporting;
  final ValueChanged<int> onSessionSelected;
  final Future<void> Function()? onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcSectionHeader(
          title: _formatSelectedDate(selectedDate),
          subtitle: sessions.isEmpty
              ? 'No sessions on this date'
              : '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
          compact: true,
        ),
        const SizedBox(height: RpcSpacing.sm),
        if (loadingDay)
          const Padding(
            padding: EdgeInsets.all(RpcSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (sessions.isEmpty)
          RpcCard(
            padding: const EdgeInsets.all(RpcSpacing.md),
            child: Text(
              'Select another date or end a live session to build history.',
              style: RpcTypography.bodyMuted(context),
            ),
          )
        else ...[
          RpcCard(
            padding: const EdgeInsets.all(RpcSpacing.sm),
            child: Column(
              children: [
                for (var i = 0; i < sessions.length; i++)
                  _SessionListTile(
                    session: sessions[i],
                    selected: sessions[i].id == selectedSessionId,
                    onTap: () => onSessionSelected(sessions[i].id),
                    showDivider: i < sessions.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: RpcSpacing.sm),
          if (loadingDetail)
            const Padding(
              padding: EdgeInsets.all(RpcSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (detail != null)
            SessionHistoryDetailView(
              detail: detail!,
              onExport: onExport == null ? null : () => onExport!(),
              exporting: exporting,
            ),
        ],
      ],
    );
  }

  String _formatSelectedDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${months[date.month - 1]} ${date.day}';
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.selected,
    required this.onTap,
    this.showDivider = false,
  });

  final SessionHistorySummary session;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isActive = session.status != 'ended';
    final mode = MatchModes.byId(session.matchMode);
    final timeLabel = _formatSessionTime(session);

    return Column(
      children: [
        Material(
          color: selected ? c.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: RpcSpacing.sm,
                vertical: RpcSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                border: Border.all(
                  color: selected ? c.primary : Colors.transparent,
                  width: selected ? 1.5 : 0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? c.primary.withValues(alpha: 0.15)
                          : c.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      mode.icon,
                      size: 16,
                      color: selected ? c.primary : c.textMuted,
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: RpcTypography.bodySemibold(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            session.matchModeLabel,
                            '${session.totalMatches}M',
                            '${session.playerCount}P',
                            if (timeLabel != null) timeLabel,
                          ].join(' · '),
                          style: RpcTypography.caption(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.xs),
                  RpcStatusBadge(
                    label: isActive ? 'Live' : 'Ended',
                    tone: isActive
                        ? RpcBadgeTone.success
                        : RpcBadgeTone.neutral,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: c.border),
      ],
    );
  }

  String? _formatSessionTime(SessionHistorySummary session) {
    final started = session.startedAt;
    if (started == null) return null;
    final parsed = DateTime.tryParse(started);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
