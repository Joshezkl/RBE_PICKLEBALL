import 'package:flutter/material.dart';

import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';

class AudioToggleButton extends StatelessWidget {
  const AudioToggleButton({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Tooltip(
      message: enabled
          ? 'Turn off venue audio'
          : 'Turn on match announcements and celebration sounds',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!enabled),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? RpcSpacing.sm : RpcSpacing.md,
              vertical: compact ? 4 : RpcSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: compact ? 18 : 20,
                  color: enabled ? c.primary : c.textMuted,
                ),
                if (!compact) ...[
                  const SizedBox(width: RpcSpacing.sm),
                  Text(
                    'Venue Audio',
                    style: RpcTypography.caption(context).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: enabled ? c.text : c.textMuted,
                    ),
                  ),
                ],
                SizedBox(width: compact ? 4 : RpcSpacing.xs),
                Switch.adaptive(
                  value: enabled,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
