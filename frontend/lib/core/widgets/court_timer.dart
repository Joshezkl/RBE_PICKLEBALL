import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

/// Live elapsed timer for an in-progress court match.
class CourtTimer extends StatefulWidget {
  const CourtTimer({
    super.key,
    this.startedAt,
    this.elapsedSeconds,
    this.compact = false,
  });

  final String? startedAt;
  final int? elapsedSeconds;
  final bool compact;

  @override
  State<CourtTimer> createState() => _CourtTimerState();
}

class _CourtTimerState extends State<CourtTimer> {
  Timer? _tick;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _syncElapsed();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _syncElapsed());
  }

  @override
  void didUpdateWidget(CourtTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.elapsedSeconds != widget.elapsedSeconds) {
      _syncElapsed();
    }
  }

  void _syncElapsed() {
    if (widget.elapsedSeconds != null) {
      if (mounted) setState(() => _elapsed = widget.elapsedSeconds!);
      return;
    }

    if (widget.startedAt == null) return;
    final start = DateTime.tryParse(widget.startedAt!);
    if (start == null) return;
    final next = DateTime.now().difference(start).inSeconds;
    if (mounted && next != _elapsed) setState(() => _elapsed = next);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final label = _format(_elapsed);

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: c.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: RpcTypography.caption(context).copyWith(
              color: c.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: c.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: RpcTypography.bodyBold(context).copyWith(
              color: c.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
