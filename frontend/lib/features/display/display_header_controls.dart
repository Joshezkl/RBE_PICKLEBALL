import 'package:flutter/material.dart';

import '../../core/display_url.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../main.dart' show rpcThemeController;
import 'audio_toggle_button.dart';

class DisplayToolbar extends StatelessWidget {
  const DisplayToolbar({
    super.key,
    required this.audioEnabled,
    required this.onAudioChanged,
    required this.showAudio,
  });

  final bool audioEnabled;
  final ValueChanged<bool> onAudioChanged;
  final bool showAudio;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Material(
      color: c.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAudio)
            AudioToggleButton(
              enabled: audioEnabled,
              onChanged: onAudioChanged,
              compact: true,
            ),
          ThemeToggleButton(controller: rpcThemeController),
        ],
      ),
    );
  }
}

bool sessionDisplayShowAudio() =>
    displayAnnounceEnabledFromUri() || displaySoundsEnabledFromUri();

bool tournamentDisplayShowAudio() =>
    tournamentAnnouncementsEnabledFromUri() ||
    tournamentCelebrationsEnabledFromUri() ||
    tournamentVoiceEnabledFromUri();

class DisplayLiveClock extends StatefulWidget {
  const DisplayLiveClock({super.key});

  @override
  State<DisplayLiveClock> createState() => _DisplayLiveClockState();
}

class _DisplayLiveClockState extends State<DisplayLiveClock>
    with SingleTickerProviderStateMixin {
  late DateTime _now;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      setState(() => _now = DateTime.now());
      return true;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour > 12
        ? _now.hour - 12
        : (_now.hour == 0 ? 12 : _now.hour);
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    final minute = _now.minute.toString().padLeft(2, '0');
    final c = context.rpc;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.success.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Icon(
                  Icons.fiber_manual_record_rounded,
                  size: 8,
                  color: c.success,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: RpcTypography.labelSemibold(context).copyWith(
                  color: c.success,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.schedule_outlined, size: 14, color: c.textMuted),
        const SizedBox(width: 4),
        Text(
          '$hour:$minute $period',
          style: RpcTypography.bodySemibold(context).copyWith(
            fontSize: 13,
            color: c.textMuted,
          ),
        ),
      ],
    );
  }
}
