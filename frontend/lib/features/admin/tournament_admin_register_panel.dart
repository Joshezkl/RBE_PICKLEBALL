import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/tournament_models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_responsive.dart';
import 'tournament_draw_lots.dart';

enum TournamentRegisterMode { direct, drawLots }

/// Parses desk-style bulk registration text into teams/players.
///
/// Singles: one player per line.
/// Doubles (and mixed): one team per line with partners separated by `-`.
List<List<String>> parseTournamentBulkEntries(
  String text,
  TournamentCategoryDefinition definition,
) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  final entries = <List<String>>[];

  for (final line in lines) {
    if (definition.playersPerTeam == 1) {
      entries.add([line]);
      continue;
    }

    if (!line.contains('-')) {
      throw FormatException(
        'Use "-" between partners on each line. Invalid line: "$line"',
      );
    }

    final parts = line
        .split('-')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length != definition.playersPerTeam) {
      throw FormatException(
        'Expected ${definition.playersPerTeam} names on "$line" '
        '(use "-" between partners).',
      );
    }

    entries.add(parts);
  }

  return entries;
}

class TournamentAdminRegisterPanel extends StatefulWidget {
  const TournamentAdminRegisterPanel({
    super.key,
    required this.category,
    required this.categoryDefinition,
    required this.onRegister,
    this.onDrawLots,
    this.isLive = false,
    this.showDrawLots = true,
  });

  final TournamentCategoryState category;
  final TournamentCategoryDefinition categoryDefinition;
  final Future<void> Function(List<String> playerNames) onRegister;
  final Future<void> Function({
    required List<String> playerNames,
    List<String>? genders,
  })? onDrawLots;
  final bool isLive;
  final bool showDrawLots;

  @override
  State<TournamentAdminRegisterPanel> createState() =>
      _TournamentAdminRegisterPanelState();
}

class _TournamentAdminRegisterPanelState
    extends State<TournamentAdminRegisterPanel> {
  final _bulkController = TextEditingController();
  bool _submitting = false;
  String? _error;
  TournamentRegisterMode _mode = TournamentRegisterMode.direct;

  bool get _canDrawLots =>
      widget.showDrawLots &&
      supportsDrawLots(widget.categoryDefinition) &&
      widget.onDrawLots != null;

  @override
  void dispose() {
    _bulkController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_submitting) return false;
    return _bulkController.text.trim().isNotEmpty;
  }

  String get _formatHint {
    if (_mode == TournamentRegisterMode.drawLots) {
      return drawLotsFormatHint(widget.categoryDefinition);
    }
    return directTeamsFormatHint(widget.categoryDefinition);
  }

  String get _submitLabel {
    final text = _bulkController.text.trim();
    if (text.isEmpty) {
      if (_mode == TournamentRegisterMode.drawLots) {
        return 'Draw lots';
      }
      return widget.categoryDefinition.playersPerTeam == 1
          ? 'Add players'
          : 'Add teams';
    }

    try {
      if (_mode == TournamentRegisterMode.drawLots) {
        final count = buildDrawLotsPairs(
          parseDrawLotsLines(text),
          widget.categoryDefinition,
        ).length;
        return count <= 1 ? 'Draw lots' : 'Draw lots ($count teams)';
      }

      final count =
          parseTournamentBulkEntries(text, widget.categoryDefinition).length;
      if (count <= 1) {
        return widget.categoryDefinition.playersPerTeam == 1
            ? 'Add player'
            : 'Add team';
      }
      return widget.categoryDefinition.playersPerTeam == 1
          ? 'Add $count players'
          : 'Add $count teams';
    } catch (_) {
      if (_mode == TournamentRegisterMode.drawLots) return 'Draw lots';
      return widget.categoryDefinition.playersPerTeam == 1
          ? 'Add players'
          : 'Add teams';
    }
  }

  Future<void> _submitDirect() async {
    final entries = parseTournamentBulkEntries(
      _bulkController.text,
      widget.categoryDefinition,
    );

    if (entries.isEmpty) return;

    var registered = 0;
    for (final names in entries) {
      await widget.onRegister(names);
      registered++;
    }

    _bulkController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            registered == 1
                ? (widget.categoryDefinition.playersPerTeam == 1
                    ? 'Player registered'
                    : 'Team registered')
                : (widget.categoryDefinition.playersPerTeam == 1
                    ? '$registered players registered'
                    : '$registered teams registered'),
          ),
        ),
      );
    }
  }

  Future<void> _submitDrawLots() async {
    final players = parseDrawLotsLines(_bulkController.text);
    final pairs = buildDrawLotsPairs(players, widget.categoryDefinition);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: RpcLayout.dialogInsetPadding(context),
        title: const Text('Confirm pairings'),
        content: ConstrainedBox(
          constraints: RpcLayout.dialogConstraints(context, maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pairs.length} team(s):',
                  style: RpcTypography.bodyMuted(context),
                ),
                const SizedBox(height: RpcSpacing.sm),
                for (var i = 0; i < pairs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Team ${i + 1}: ${pairs[i].names.join(' - ')}',
                      style: RpcTypography.body(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Register ${pairs.length}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.onDrawLots!(
      playerNames: players.map((player) => player.name).toList(),
      genders: players.every((player) => player.gender != null)
          ? players.map((player) => player.gender!).toList()
          : null,
    );

    _bulkController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pairs.length == 1
                ? 'Draw lots complete — 1 team registered'
                : 'Draw lots complete — ${pairs.length} teams registered',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_mode == TournamentRegisterMode.drawLots) {
        await _submitDrawLots();
      } else {
        await _submitDirect();
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isLive ? 'Add late participants' : 'Register players',
          style: RpcTypography.bodySemibold(context),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isLive
              ? 'Late entrants join the smallest group and are scheduled for remaining round robin matches.'
              : 'Groups are assigned when play starts.',
          style: RpcTypography.caption(context).copyWith(color: c.textMuted),
        ),
        if (_canDrawLots) ...[
          const SizedBox(height: RpcSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<TournamentRegisterMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TournamentRegisterMode.direct,
                  label: Text('Teams'),
                ),
                ButtonSegment(
                  value: TournamentRegisterMode.drawLots,
                  label: Text('Draw lots'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _submitting
                  ? null
                  : (selection) {
                      setState(() {
                        _mode = selection.first;
                        _error = null;
                      });
                    },
            ),
          ),
        ],
        const SizedBox(height: RpcSpacing.xs),
        Text(
          _formatHint,
          style: RpcTypography.caption(context).copyWith(
            color: c.textMuted.withValues(alpha: 0.9),
            height: 1.45,
          ),
        ),
        const SizedBox(height: RpcSpacing.sm),
        TextField(
          controller: _bulkController,
          enabled: !_submitting,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: _mode == TournamentRegisterMode.drawLots
                ? 'One player per line'
                : 'Paste or type names here',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {
            _error = null;
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: RpcSpacing.xs),
          Text(
            _error!,
            style: RpcTypography.caption(context).copyWith(color: c.danger),
          ),
        ],
        const SizedBox(height: RpcSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _mode == TournamentRegisterMode.drawLots
                        ? Icons.shuffle_rounded
                        : Icons.person_add_rounded,
                    size: 18,
                  ),
            label: Text(_submitLabel),
          ),
        ),
      ],
    );
  }
}

String tournamentGenderForPlayerSlot(
  TournamentCategoryDefinition definition,
  int index,
) {
  if (definition.requiresMixed) {
    return index == 0 ? 'male' : 'female';
  }
  return definition.genderRestriction ?? 'male';
}
