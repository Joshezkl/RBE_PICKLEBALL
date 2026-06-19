import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

/// Compact, centered Team A | VS | Team B layout.
class CourtMatchLayout extends StatelessWidget {
  const CourtMatchLayout({
    super.key,
    this.match,
    required this.slotsPerTeam,
    this.dense = false,
    this.showTeamLabels = true,
    this.onRemovePlayer,
  });

  final MatchInfo? match;
  final int slotsPerTeam;
  final bool dense;
  final bool showTeamLabels;
  final void Function(int playerId)? onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    final teamA = _teamPlayers(match?.teamA, slotsPerTeam);
    final teamB = _teamPlayers(match?.teamB, slotsPerTeam);
    final compactDisplay = dense && !showTeamLabels;
    final avatarSize = dense ? (compactDisplay ? 30.0 : 36.0) : 50.0;
    final slotGap = dense ? (compactDisplay ? 3.0 : 5.0) : 10.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _TeamColumn(
              label: 'Team A',
              players: teamA,
              slotLabels: _slotLabels(slotsPerTeam, 'A'),
              avatarSize: avatarSize,
              slotGap: slotGap,
              dense: dense,
              showTeamLabel: showTeamLabels,
              onRemovePlayer: onRemovePlayer,
            ),
          ),
          _VsBadge(dense: dense, avatarSize: avatarSize),
          Expanded(
            child: _TeamColumn(
              label: 'Team B',
              players: teamB,
              slotLabels: _slotLabels(slotsPerTeam, 'B'),
              avatarSize: avatarSize,
              slotGap: slotGap,
              dense: dense,
              showTeamLabel: showTeamLabels,
              onRemovePlayer: onRemovePlayer,
            ),
          ),
        ],
      ),
    );
  }

  List<MatchPlayer?> _teamPlayers(Map<String, MatchPlayer?>? team, int slots) {
    if (team == null) return List.filled(slots, null);
    return [team['player1'], if (slots > 1) team['player2']];
  }

  List<String> _slotLabels(int slots, String team) {
    if (slots == 1) return [team == 'A' ? 'Player 1' : 'Player 2'];
    if (team == 'A') return ['Player 1', 'Player 2'];
    return ['Player 3', 'Player 4'];
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.dense, required this.avatarSize});

  final bool dense;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final size = dense ? (avatarSize * 0.9) : 46.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.background,
              c.surfaceHover,
            ],
          ),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.text.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'VS',
          style: (dense
                  ? RpcTypography.caption(context)
                  : RpcTypography.bodyBold(context))
              .copyWith(
            fontStyle: FontStyle.italic,
            color: c.text.withValues(alpha: 0.75),
            letterSpacing: -0.5,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.label,
    required this.players,
    required this.slotLabels,
    required this.avatarSize,
    required this.slotGap,
    this.dense = false,
    this.showTeamLabel = true,
    this.onRemovePlayer,
  });

  final String label;
  final List<MatchPlayer?> players;
  final List<String> slotLabels;
  final double avatarSize;
  final double slotGap;
  final bool dense;
  final bool showTeamLabel;
  final void Function(int playerId)? onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTeamLabel) ...[
          _TeamLabel(text: label, dense: dense),
          SizedBox(height: dense ? slotGap : slotGap + 2),
        ],
        ...List.generate(players.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < players.length - 1 ? slotGap : 0),
            child: PlayerSlot(
              player: players[i],
              label: slotLabels[i],
              size: avatarSize,
              dense: dense,
              onRemove: players[i] != null && onRemovePlayer != null
                  ? () => onRemovePlayer!(players[i]!.id)
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _TeamLabel extends StatelessWidget {
  const _TeamLabel({required this.text, this.dense = false});

  final String text;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: c.surfaceHover,
        borderRadius: BorderRadius.circular(dense ? 5 : 6),
      ),
      child: Text(
        text,
        style: (dense
                ? RpcTypography.caption(context)
                : RpcTypography.bodyBold(context))
            .copyWith(
          color: c.textMuted,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PlayerSlot extends StatelessWidget {
  const PlayerSlot({
    super.key,
    required this.player,
    required this.label,
    required this.size,
    this.dense = false,
    this.onRemove,
  });

  final MatchPlayer? player;
  final String label;
  final double size;
  final bool dense;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        player != null
            ? _PlayerAvatar(
                player: player!,
                size: size,
                onRemove: onRemove,
              )
            : _EmptySlot(size: size),
        SizedBox(height: dense ? (size <= 30 ? 2 : 3) : 5),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size + (dense ? 28 : 36)),
          child: Text(
            player?.name ?? label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (player != null
                    ? (dense
                        ? RpcTypography.caption(context)
                        : RpcTypography.bodySemibold(context))
                    : (dense
                        ? RpcTypography.caption(context)
                        : RpcTypography.bodyMuted(context)))
                .copyWith(
              height: 1.2,
              fontWeight: player != null ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.player,
    required this.size,
    this.onRemove,
  });

  final MatchPlayer player;
  final double size;
  final VoidCallback? onRemove;

  String get _initials {
    final parts = player.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final avatar = Container(
      width: size + 4,
      height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primary.withValues(alpha: 0.5),
            c.primary.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface,
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: TextStyle(
              color: c.primary,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.32,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );

    if (onRemove == null) {
      return avatar;
    }

    final removeSize = size < 40 ? 18.0 : 20.0;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: -2,
            right: -2,
            child: Material(
              color: c.danger.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Remove from court',
                  child: SizedBox(
                    width: removeSize,
                    height: removeSize,
                    child: Icon(
                      Icons.close_rounded,
                      size: removeSize * 0.65,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.background,
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Icon(
        Icons.person_add_alt_1_outlined,
        size: size * 0.32,
        color: c.textMuted.withValues(alpha: 0.45),
      ),
    );
  }
}
