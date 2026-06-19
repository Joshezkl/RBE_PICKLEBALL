import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';

class MatchModeSelection extends StatelessWidget {
  const MatchModeSelection({
    super.key,
    required this.selectedModeId,
    required this.onModeSelected,
    this.compact = false,
  });

  final String selectedModeId;
  final ValueChanged<String> onModeSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactMatchModePicker(
        selectedModeId: selectedModeId,
        onModeSelected: onModeSelected,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : RpcSpacing.pageMaxWidth;
        final crossAxisCount = width >= RpcBreakpoints.wide
            ? 3
            : width >= RpcBreakpoints.compact
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MatchModes.all.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: RpcSpacing.sm,
            mainAxisSpacing: RpcSpacing.sm,
            mainAxisExtent: crossAxisCount == 1 ? 168.0 : 176.0,
          ),
          itemBuilder: (context, index) {
            final mode = MatchModes.all[index];
            final selected = mode.id == selectedModeId;

            return _MatchModeCard(
              mode: mode,
              selected: selected,
              onTap: () => onModeSelected(mode.id),
            );
          },
        );
      },
    );
  }
}

class _CompactMatchModePicker extends StatelessWidget {
  const _CompactMatchModePicker({
    required this.selectedModeId,
    required this.onModeSelected,
  });

  final String selectedModeId;
  final ValueChanged<String> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final selected = MatchModes.byId(selectedModeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: RpcSpacing.xs,
          runSpacing: RpcSpacing.xs,
          children: [
            for (final mode in MatchModes.all)
              _MatchModeChip(
                mode: mode,
                selected: mode.id == selectedModeId,
                onTap: () => onModeSelected(mode.id),
              ),
          ],
        ),
        const SizedBox(height: RpcSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RpcSpacing.sm,
            vertical: RpcSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected.icon,
                size: 16,
                color: c.primary,
              ),
              const SizedBox(width: RpcSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            selected.name,
                            style: RpcTypography.caption(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selected.recommended) ...[
                          const SizedBox(width: 6),
                          _MiniBadge(label: 'Recommended', color: c.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.description,
                      style: RpcTypography.caption(context).copyWith(
                        color: c.textMuted,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchModeChip extends StatelessWidget {
  const _MatchModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MatchModeDefinition mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Material(
      color: selected ? c.primary.withValues(alpha: 0.12) : c.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                size: 15,
                color: selected ? c.primary : c.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                mode.name,
                style: RpcTypography.caption(context).copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? c.primary : c.text,
                  fontSize: 12,
                ),
              ),
              if (mode.recommended) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: selected ? c.primary : c.success,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: RpcTypography.caption(context).copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MatchModeCard extends StatelessWidget {
  const _MatchModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MatchModeDefinition mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Material(
      color: selected ? c.primaryLight : c.surface,
      borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(RpcSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.primary.withValues(alpha: 0.15)
                          : c.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      mode.icon,
                      size: 20,
                      color: selected ? c.primary : c.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mode.name,
                      style: RpcTypography.bodyBold(context),
                    ),
                  ),
                  if (mode.recommended)
                    _MiniBadge(label: 'Recommended', color: c.success),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mode.description,
                style: RpcTypography.bodySmallMuted(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Best for: ${mode.useCase}',
                style: RpcTypography.caption(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
