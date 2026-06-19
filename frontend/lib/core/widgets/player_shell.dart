import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import '../decor/pickleball_ball_painter.dart';
import '../decor/rpc_court_background.dart';
import '../decor/rpc_decor_theme.dart';
import 'brand_logo.dart';
import 'rpc_responsive.dart';
import 'theme_toggle_button.dart';
import '../../main.dart' show rpcThemeController;

enum PlayerFlowStep { checkIn, onQueue, playing }

class PlayerShell extends StatelessWidget {
  const PlayerShell({
    super.key,
    required this.title,
    required this.sessionName,
    this.sessionDetail,
    this.activeStep,
    required this.child,
    this.maxWidth = 520,
  });

  final String title;
  final String sessionName;
  final String? sessionDetail;
  final PlayerFlowStep? activeStep;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ballColor = RpcDecorOpacity.lineColor(
      context,
      alpha: RpcDecorOpacity.watermark(context, RpcDecorIntensity.subtle),
    );

    return Scaffold(
      backgroundColor: context.rpc.background,
      body: RpcCourtBackground(
        showLogoWatermark: false,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final effectiveMax = RpcLayout.effectiveMaxWidth(
                constraints.maxWidth,
                preferred: maxWidth,
              );
              final padding = RpcLayout.pagePadding(constraints.maxWidth);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: effectiveMax),
                  child: SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            BrandLogo(
                              height: RpcLayout.isCompact(constraints.maxWidth)
                                  ? 36
                                  : 40,
                            ),
                            const Spacer(),
                            ThemeToggleButton(controller: rpcThemeController),
                          ],
                        ),
                        const SizedBox(height: RpcSpacing.md),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: -8,
                              top: -12,
                              child: IgnorePointer(
                                child: CustomPaint(
                                  size: const Size(72, 72),
                                  painter:
                                      PickleballBallPainter(color: ballColor),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  style: RpcTypography.headline(context),
                                ),
                                const SizedBox(height: RpcSpacing.xs),
                                Text(
                                  sessionName,
                                  style: RpcTypography.subtitle(context),
                                ),
                                if (sessionDetail != null) ...[
                                  const SizedBox(height: RpcSpacing.xs),
                                  Text(
                                    sessionDetail!,
                                    style:
                                        RpcTypography.bodySmallMuted(context),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (activeStep != null) ...[
                          const SizedBox(height: RpcSpacing.md),
                          _PlayerStepIndicator(activeStep: activeStep!),
                        ],
                        const SizedBox(height: RpcSpacing.md),
                        child,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerStepIndicator extends StatelessWidget {
  const _PlayerStepIndicator({required this.activeStep});

  final PlayerFlowStep activeStep;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Check in', PlayerFlowStep.checkIn),
      ('On queue', PlayerFlowStep.onQueue),
      ('Playing', PlayerFlowStep.playing),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: _stepIndex(activeStep) >= i
                    ? context.rpc.primary.withValues(alpha: 0.4)
                    : context.rpc.border,
              ),
            ),
          _StepDot(
            label: steps[i].$1,
            active: activeStep == steps[i].$2,
            completed: _stepIndex(activeStep) > _stepIndex(steps[i].$2),
          ),
        ],
      ],
    );
  }

  int _stepIndex(PlayerFlowStep step) => switch (step) {
        PlayerFlowStep.checkIn => 0,
        PlayerFlowStep.onQueue => 1,
        PlayerFlowStep.playing => 2,
      };
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.active,
    required this.completed,
  });

  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final color = active || completed ? c.primary : c.textMuted;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? c.primary
                : completed
                    ? c.primaryLight
                    : c.surfaceHover,
            border: Border.all(
              color: active || completed ? c.primary : c.border,
            ),
          ),
          alignment: Alignment.center,
          child: completed && !active
              ? Icon(Icons.check_rounded, size: 16, color: c.primary)
              : active
                  ? Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: RpcTypography.caption(context).copyWith(
            color: color,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

PlayerFlowStep playerFlowStepFromStatus(String? status) {
  return switch (status) {
    'playing' => PlayerFlowStep.playing,
    'queued' || 'away' => PlayerFlowStep.onQueue,
    _ => PlayerFlowStep.checkIn,
  };
}
