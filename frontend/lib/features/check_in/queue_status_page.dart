import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/check_in_client.dart';
import '../../core/check_in_url.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/player_shell.dart';
import '../../core/widgets/player_status_card.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';

class QueueStatusPage extends StatefulWidget {
  const QueueStatusPage({
    super.key,
    this.token,
    this.clubPlayerId,
    this.playerId,
  });

  final String? token;
  final int? clubPlayerId;
  final int? playerId;

  @override
  State<QueueStatusPage> createState() => _QueueStatusPageState();
}

class _QueueStatusPageState extends State<QueueStatusPage> {
  CheckInClient? _client;

  CheckInSessionInfo? _session;
  CheckInPlayerStatus? _status;
  List<SessionRosterPlayer> _roster = [];

  int? _clubPlayerId;
  int? _playerId;

  final _searchController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  bool _pickerMode = false;
  bool _sessionReady = false;
  String? _fatalError;
  String? _searchError;
  Timer? _statusPoll;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _clubPlayerId = widget.clubPlayerId ?? clubPlayerIdFromUri();
    _playerId = widget.playerId ?? playerIdFromUri();
    _initWithToken(widget.token ?? checkInTokenFromUri());
  }

  void _initWithToken(String? token) {
    _session = null;
    _status = null;
    _roster = [];
    _sessionReady = false;
    _pickerMode = false;
    _fatalError = null;
    _searchError = null;

    if (token != null && token.isNotEmpty) {
      _client = CheckInClient(token: token);
      _bootstrap();
    } else {
      _client = null;
      _loading = false;
      _fatalError = 'Invalid link — scan the Queue Status QR code at the court';
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _fatalError = null;
      _searchError = null;
      _sessionReady = false;
    });
    try {
      final session = await _client!.getSession();
      if (!mounted) return;
      setState(() {
        _session = session;
        _sessionReady = true;
      });

      if (_clubPlayerId != null || _playerId != null) {
        await _loadStatus();
      } else {
        setState(() => _pickerMode = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fatalError = _friendlyError(e);
        _session = null;
        _sessionReady = false;
        _pickerMode = false;
        _roster = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _client!.getStatus(
        clubPlayerId: _clubPlayerId,
        playerId: _playerId,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _pickerMode = false;
        _fatalError = null;
        _clubPlayerId = status.clubPlayerId ?? _clubPlayerId;
        _playerId = status.playerId ?? _playerId;
      });
      _startStatusPoll();
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      if (_isInvalidLinkError(e)) {
        setState(() {
          _fatalError = message;
          _sessionReady = false;
          _status = null;
          _pickerMode = false;
        });
      } else {
        setState(() {
          _fatalError = message;
          _pickerMode = true;
          _status = null;
        });
      }
    }
  }

  void _startStatusPoll() {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_clubPlayerId != null || _playerId != null) {
        _client!
            .getStatus(clubPlayerId: _clubPlayerId, playerId: _playerId)
            .then((status) {
          if (mounted) setState(() => _status = status);
        }).catchError((_) {});
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (!_sessionReady || _client == null) return;

    if (query.trim().isEmpty) {
      setState(() {
        _roster = [];
        _searchError = null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchRoster(query.trim());
    });
  }

  Future<void> _searchRoster(String query) async {
    final requestId = ++_searchRequestId;
    try {
      final roster = await _client!.searchSessionRoster(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _roster = roster;
        _searchError = null;
        _fatalError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      if (_isInvalidLinkError(e)) {
        setState(() {
          _fatalError = _friendlyError(e);
          _sessionReady = false;
          _session = null;
          _roster = [];
          _pickerMode = false;
        });
      } else {
        setState(() => _searchError = _friendlyError(e));
      }
    }
  }

  void _selectPlayer(SessionRosterPlayer player) {
    setState(() {
      _clubPlayerId = player.clubPlayerId;
      _playerId = player.playerId;
      _pickerMode = false;
      _searchError = null;
    });
    _loadStatus();
  }

  Future<void> _stepOut() async {
    setState(() => _submitting = true);
    try {
      final status = await _client!.stepOut(
        clubPlayerId: _clubPlayerId,
        playerId: _playerId,
      );
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _fatalError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _stepBack() async {
    setState(() => _submitting = true);
    try {
      final status = await _client!.stepBack(
        clubPlayerId: _clubPlayerId,
        playerId: _playerId,
      );
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _fatalError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isInvalidLinkError(Object e) {
    if (e is ApiException) {
      return e.statusCode == 404 ||
          e.message.contains('Invalid or expired check-in link') ||
          e.message.contains('Check-in token is required');
    }
    final text = e.toString();
    return text.contains('Invalid or expired check-in link') ||
        text.contains('Check-in token is required');
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    final text = e.toString();
    if (text.startsWith('ApiException: ')) {
      return text.substring('ApiException: '.length);
    }
    return text;
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerShell(
      title: 'Where Am I?',
      sessionName: _session?.sessionName ?? 'Live queue status',
      activeStep: _status != null
          ? playerFlowStepFromStatus(_status!.status)
          : null,
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fatalError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.md),
              child: RpcErrorBanner(
                message: _fatalError!,
                onDismiss: () => setState(() => _fatalError = null),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_sessionReady)
            _buildInvalidLinkCard()
          else if (_pickerMode)
            _buildPicker()
          else if (_status != null)
            PlayerStatusCard(
              status: _status!,
              submitting: _submitting,
              onStepOut: _status!.status != 'playing' ? _stepOut : null,
              onStepBack: _stepBack,
            )
          else
            _buildPicker(),
          if (_sessionReady && !_pickerMode && _status != null) ...[
            const SizedBox(height: RpcSpacing.md),
            TextButton(
              onPressed: () => setState(() {
                _pickerMode = true;
                _status = null;
                _searchError = null;
                _statusPoll?.cancel();
              }),
              child: const Text('Look up a different player'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvalidLinkCard() {
    return RpcCard(
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 48,
            color: context.rpc.textMuted,
          ),
          const SizedBox(height: RpcSpacing.md),
          Text(
            'Scan the QR code',
            style: RpcTypography.title(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RpcSpacing.sm),
          Text(
            'Open the Queue Status QR from the admin board or check-in desk. '
            'Links expire when the session ends.',
            style: RpcTypography.bodyMuted(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Find yourself', style: RpcTypography.title(context)),
          const SizedBox(height: RpcSpacing.sm),
          Text(
            'Search checked-in players to see your queue position or court.',
            style: RpcTypography.bodySmallMuted(context),
          ),
          const SizedBox(height: RpcSpacing.md),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _onSearchChanged,
          ),
          if (_searchError != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            Text(
              _searchError!,
              style: RpcTypography.bodySmallMuted(context).copyWith(
                color: context.rpc.danger,
              ),
            ),
          ],
          const SizedBox(height: RpcSpacing.md),
          if (_roster.isEmpty)
            Text(
              'Start typing your name',
              style: RpcTypography.bodyMuted(context),
            )
          else
            ..._roster.take(8).map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: RpcSpacing.sm),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(RpcSpacing.inputRadius),
                        side: BorderSide(color: context.rpc.border),
                      ),
                      title: Text(player.name),
                      subtitle: player.isGuest
                          ? const Text('Guest player')
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _selectPlayer(player),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
