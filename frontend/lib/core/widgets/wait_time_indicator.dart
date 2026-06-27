import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

/// Live indicator showing how long a player has been waiting in the queue.
///
/// Ticks every second and renders a human-friendly duration such as
/// `45s`, `5m 12s`, or `2h 03m`.
class WaitTimeIndicator extends StatefulWidget {
  const WaitTimeIndicator({
    super.key,
    required this.since,
    this.compact = false,
  });

  /// The moment the player joined the queue.
  final DateTime? since;
  final bool compact;

  @override
  State<WaitTimeIndicator> createState() => _WaitTimeIndicatorState();
}

class _WaitTimeIndicatorState extends State<WaitTimeIndicator> {
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncElapsed();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _syncElapsed());
  }

  @override
  void didUpdateWidget(WaitTimeIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) {
      _syncElapsed();
    }
  }

  void _syncElapsed() {
    final since = widget.since;
    if (since == null) return;
    var next = DateTime.now().difference(since);
    if (next.isNegative) next = Duration.zero;
    if (mounted && next.inSeconds != _elapsed.inSeconds) {
      setState(() => _elapsed = next);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    if (widget.since == null) return const SizedBox.shrink();

    final label = _format(_elapsed);
    final iconSize = widget.compact ? 12.0 : 13.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: iconSize, color: c.textMuted),
        const SizedBox(width: 4),
        Text(
          '$label waiting',
          style: RpcTypography.bodySmallMuted(context).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
