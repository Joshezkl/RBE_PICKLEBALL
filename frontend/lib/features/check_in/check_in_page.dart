import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/check_in_client.dart';
import '../../core/check_in_url.dart';
import '../../core/widgets/player_status_card.dart';
import '../../core/widgets/player_shell.dart';
import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/collapsible_section.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/rpc_status_badge.dart';
import 'queue_status_page.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, this.token});

  final String? token;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  late final String? _token;
  CheckInClient? _client;

  CheckInSessionInfo? _session;
  List<ClubPlayerInfo> _players = [];
  CheckInPlayerStatus? _myStatus;
  int? _checkedInClubPlayerId;

  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  String _skillLevel = 'beginner';
  String _gender = 'male';
  bool _isGuest = false;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Timer? _statusPoll;

  bool get _isCheckedIn => _myStatus != null;

  @override
  void initState() {
    super.initState();
    _token = widget.token ?? checkInTokenFromUri();
    final token = _token;
    if (token != null && token.isNotEmpty) {
      _client = CheckInClient(token: token);
      _bootstrap();
    } else {
      _loading = false;
      _error = 'Invalid check-in link — scan the QR code at the court';
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _client!.getSession();
      final players = await _client!.searchPlayers('');
      if (!mounted) return;
      setState(() {
        _session = session;
        _players = players;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startStatusPoll(int clubPlayerId) {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStatus(clubPlayerId);
    });
  }

  Future<void> _refreshStatus(int clubPlayerId) async {
    try {
      final status = await _client!.getStatus(clubPlayerId: clubPlayerId);
      if (mounted) setState(() => _myStatus = status);
    } catch (_) {}
  }

  Future<void> _search(String query) async {
    try {
      final players = await _client!.searchPlayers(query);
      if (mounted) setState(() => _players = players);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _joinPlayer(ClubPlayerInfo player) async {
    if (_submitting || player.inCurrentSession) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final status = await _client!.join(player.id);
      if (!mounted) return;
      setState(() {
        _myStatus = status;
        _checkedInClubPlayerId = player.id;
      });
      _startStatusPoll(player.id);
      await _search(_searchController.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _registerAndJoin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _client!.register(
        name: name,
        skillLevel: _skillLevel,
        gender: _gender,
        isGuest: _isGuest,
      );
      if (!mounted) return;
      setState(() {
        _myStatus = result.status;
        _checkedInClubPlayerId = result.player.id;
      });
      _startStatusPoll(result.player.id);
      _nameController.clear();
      await _search(_searchController.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _stepOut() async {
    if (_checkedInClubPlayerId == null) return;
    setState(() => _submitting = true);
    try {
      final status = await _client!.stepOut(
        clubPlayerId: _checkedInClubPlayerId,
      );
      if (mounted) setState(() => _myStatus = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _stepBack() async {
    if (_checkedInClubPlayerId == null) return;
    setState(() => _submitting = true);
    try {
      final status = await _client!.stepBack(
        clubPlayerId: _checkedInClubPlayerId,
      );
      if (mounted) setState(() => _myStatus = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openQueueStatus() {
    final token = _token;
    if (token == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QueueStatusPage(
          token: token,
          clubPlayerId: _checkedInClubPlayerId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionDetail = _session != null
        ? '${_session!.matchModeLabel} · ${_session!.playFormat.toUpperCase()}'
        : null;

    return PlayerShell(
      title: 'Player Check-In',
      sessionName: _session?.sessionName ?? 'Join today\'s session',
      sessionDetail: sessionDetail,
      activeStep: _isCheckedIn
          ? playerFlowStepFromStatus(_myStatus?.status)
          : PlayerFlowStep.checkIn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            RpcErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_session != null) ...[
            if (_myStatus != null)
              PlayerStatusCard(
                status: _myStatus!,
                submitting: _submitting,
                compact: false,
                onStepOut: _myStatus!.status != 'playing' ? _stepOut : null,
                onStepBack: _stepBack,
                onOpenFullStatus: _openQueueStatus,
              ),
            if (_myStatus != null) const SizedBox(height: RpcSpacing.lg),
            if (_isCheckedIn)
              CollapsibleSection(
                title: 'Check in another player',
                subtitle: 'Search the registry or register someone new',
                initiallyExpanded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExistingPlayersCard(
                      players: _players,
                      searchController: _searchController,
                      submitting: _submitting,
                      checkedInId: _checkedInClubPlayerId,
                      onSearch: _search,
                      onJoin: _joinPlayer,
                    ),
                    const SizedBox(height: RpcSpacing.lg),
                    _NewPlayerCard(
                      nameController: _nameController,
                      skillLevel: _skillLevel,
                      gender: _gender,
                      requiresSkill: _session!.requiresSkillLevel,
                      requiresGender: _session!.requiresGender,
                      submitting: _submitting,
                      onSkillChanged: (v) => setState(() => _skillLevel = v!),
                      onGenderChanged: (v) => setState(() => _gender = v!),
                      isGuest: _isGuest,
                      onGuestChanged: (v) => setState(() => _isGuest = v),
                      onSubmit: _registerAndJoin,
                    ),
                  ],
                ),
              )
            else ...[
              _ExistingPlayersCard(
                players: _players,
                searchController: _searchController,
                submitting: _submitting,
                checkedInId: _checkedInClubPlayerId,
                onSearch: _search,
                onJoin: _joinPlayer,
              ),
              const SizedBox(height: RpcSpacing.lg),
              _NewPlayerCard(
                nameController: _nameController,
                skillLevel: _skillLevel,
                gender: _gender,
                requiresSkill: _session!.requiresSkillLevel,
                requiresGender: _session!.requiresGender,
                submitting: _submitting,
                onSkillChanged: (v) => setState(() => _skillLevel = v!),
                onGenderChanged: (v) => setState(() => _gender = v!),
                isGuest: _isGuest,
                onGuestChanged: (v) => setState(() => _isGuest = v),
                onSubmit: _registerAndJoin,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExistingPlayersCard extends StatelessWidget {
  const _ExistingPlayersCard({
    required this.players,
    required this.searchController,
    required this.submitting,
    required this.checkedInId,
    required this.onSearch,
    required this.onJoin,
  });

  final List<ClubPlayerInfo> players;
  final TextEditingController searchController;
  final bool submitting;
  final int? checkedInId;
  final ValueChanged<String> onSearch;
  final ValueChanged<ClubPlayerInfo> onJoin;

  @override
  Widget build(BuildContext context) {
    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Find your name', style: RpcTypography.title(context)),
          const SizedBox(height: RpcSpacing.sm),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search players',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: RpcSpacing.md),
          if (players.isEmpty)
            Text(
              'No matching players — register below if you\'re new',
              style: RpcTypography.bodyMuted(context),
            )
          else
            ...players.take(8).map((player) {
              final isMe = checkedInId == player.id;
              final inSession = player.inCurrentSession || isMe;
              return Padding(
                padding: const EdgeInsets.only(bottom: RpcSpacing.sm),
                child: Material(
                  color: context.rpc.background,
                  borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                      side: BorderSide(color: context.rpc.border),
                    ),
                    title: Text(
                      player.name,
                      style: RpcTypography.bodySemibold(context),
                    ),
                    subtitle: Text(
                      '${MatchModes.skillLabel(player.skillLevel)} · ${MatchModes.genderLabel(player.gender)}',
                      style: RpcTypography.bodySmallMuted(context),
                    ),
                    trailing: inSession
                        ? const RpcStatusBadge(
                            label: 'Checked in',
                            tone: RpcBadgeTone.success,
                          )
                        : FilledButton(
                            onPressed: submitting ? null : () => onJoin(player),
                            child: const Text('Join'),
                          ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _NewPlayerCard extends StatelessWidget {
  const _NewPlayerCard({
    required this.nameController,
    required this.skillLevel,
    required this.gender,
    required this.requiresSkill,
    required this.requiresGender,
    required this.submitting,
    required this.onSkillChanged,
    required this.isGuest,
    required this.onGuestChanged,
    required this.onGenderChanged,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final String skillLevel;
  final String gender;
  final bool requiresSkill;
  final bool requiresGender;
  final bool submitting;
  final bool isGuest;
  final ValueChanged<bool> onGuestChanged;
  final ValueChanged<String?> onSkillChanged;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isGuest ? 'One-night guest' : 'New to the club?',
            style: RpcTypography.title(context),
          ),
          const SizedBox(height: RpcSpacing.sm),
          Text(
            isGuest
                ? 'Guests play tonight only — they won\'t appear on the all-time leaderboard.'
                : 'Register once — we\'ll add you to today\'s session automatically.',
            style: RpcTypography.bodySmallMuted(context),
          ),
          const SizedBox(height: RpcSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('One-night guest', style: RpcTypography.body(context)),
            value: isGuest,
            onChanged: onGuestChanged,
          ),
          const SizedBox(height: RpcSpacing.md),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              hintText: 'Your name',
            ),
          ),
          const SizedBox(height: RpcSpacing.md),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: skillLevel,
            decoration: InputDecoration(
              labelText: requiresSkill ? 'Skill level (required)' : 'Skill level',
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'novice', child: Text('Novice')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: onSkillChanged,
          ),
          const SizedBox(height: RpcSpacing.md),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: gender,
            decoration: InputDecoration(
              labelText: requiresGender ? 'Gender (required)' : 'Gender',
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: RpcSpacing.lg),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register & Join Session'),
          ),
        ],
      ),
    );
  }
}
