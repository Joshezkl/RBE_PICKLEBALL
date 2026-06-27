import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'admin_pin_controller.dart';
import 'models.dart';
import 'tournament_models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? adminPin})
      : _client = client ?? http.Client(),
        _adminPin = adminPin;

  final http.Client _client;
  String? _adminPin;

  void setAdminPin(String? pin) => _adminPin = pin;

  String get _resolvedAdminPin {
    final global = rpcAdminPinController.pin;
    if (global.isNotEmpty) return global;
    return _adminPin?.trim() ?? '';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_resolvedAdminPin.isNotEmpty) 'X-Admin-Pin': _resolvedAdminPin,
      };

  Future<SessionState> getActiveSession() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/active'),
      headers: _headers,
    );
    if (response.statusCode == 404) {
      throw ApiException('No active session', statusCode: 404);
    }
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> getSessionState(int sessionId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/state'),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> getSessionStateLive(int sessionId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/live'),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> startSession({
    String name = 'Open Play Session',
    String matchMode = 'auto_balanced',
    String playFormat = 'doubles',
    int courtCount = 4,
    bool autoAssignEnabled = false,
    bool requirePayment = false,
    int sessionFeeCents = 3000,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'match_mode': matchMode,
        'play_format': playFormat,
        'court_count': courtCount,
        'auto_assign_enabled': autoAssignEnabled,
        'require_payment': requirePayment,
        'session_fee_cents': sessionFeeCents,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> addPlayer(
    int sessionId,
    String name, {
    String? skillLevel,
    String? gender,
    String? paymentAction,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/players'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        if (skillLevel != null) 'skill_level': skillLevel,
        if (gender != null) 'gender': gender,
        if (paymentAction != null) 'payment_action': paymentAction,
      }),
    );
    if (response.statusCode == 202) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return SessionState.fromJson(body['state'] as Map<String, dynamic>);
    }
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionState.fromJson(body['state'] as Map<String, dynamic>);
  }

  Future<SessionState> removePlayer(int sessionId, int playerId) async {
    final response = await _client.delete(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/players/$playerId',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> updatePlayerName(
    int sessionId,
    int playerId,
    String name,
  ) async {
    final response = await _client.patch(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/players/$playerId',
      ),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionState.fromJson(body['state'] as Map<String, dynamic>);
  }

  Future<SessionState> moveQueuePlayer(
    int sessionId, {
    required int playerId,
    required String queueType,
    required int position,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/queues/move'),
      headers: _headers,
      body: jsonEncode({
        'player_id': playerId,
        'queue_type': queueType,
        'position': position,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> submitScore(
    int sessionId,
    int matchId,
    int scoreA,
    int scoreB,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/matches/$matchId/score',
      ),
      headers: _headers,
      body: jsonEncode({'score_a': scoreA, 'score_b': scoreB}),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> assignNextUp(int sessionId, int courtId) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/courts/$courtId/assign-next',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> configureChallengeCourts(
    int sessionId,
    List<int> courtNumbers,
  ) async {
    final response = await _client.patch(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/configure',
      ),
      headers: _headers,
      body: jsonEncode({'court_numbers': courtNumbers}),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> openChallengeCourt(int sessionId) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/open',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> closeChallengeCourt(int sessionId) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/close',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> joinChallengeCourtTeam(
    int sessionId, {
    required int playerId,
    required int partnerId,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/join',
      ),
      headers: _headers,
      body: jsonEncode({
        'player_id': playerId,
        'partner_id': partnerId,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> returnChallengeCourtTeam(
    int sessionId,
    int teamId,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/teams/$teamId/return',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> removeChallengeCourtTeam(
    int sessionId,
    int teamId,
  ) async {
    final response = await _client.delete(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/challenge-court/teams/$teamId',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> assignChallengeCourtNext(
    int sessionId,
    int courtId,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/courts/$courtId/assign-challenge-next',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> removePlayerFromCourt(
    int sessionId,
    int courtId,
    int playerId,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/courts/$courtId/players/$playerId/remove',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> swapCourtPlayers(
    int sessionId,
    int courtId,
    int playerAId,
    int playerBId,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/courts/$courtId/swap-players',
      ),
      headers: _headers,
      body: jsonEncode({
        'player_a_id': playerAId,
        'player_b_id': playerBId,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionState> updateSessionSettings(
    int sessionId, {
    bool? autoAssignEnabled,
    bool? requirePayment,
    int? sessionFeeCents,
    int? courtCount,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/settings'),
      headers: _headers,
      body: jsonEncode({
        if (autoAssignEnabled != null) 'auto_assign_enabled': autoAssignEnabled,
        if (requirePayment != null) 'require_payment': requirePayment,
        if (sessionFeeCents != null) 'session_fee_cents': sessionFeeCents,
        if (courtCount != null) 'court_count': courtCount,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SessionPreset>> getSessionPresets() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/session-presets'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['presets'] as List<dynamic>? ?? [])
        .map((e) => SessionPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionPreset> saveSessionPreset({
    required String name,
    required String matchMode,
    required String playFormat,
    required int courtCount,
    bool autoAssignEnabled = false,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/session-presets'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'match_mode': matchMode,
        'play_format': playFormat,
        'court_count': courtCount,
        'auto_assign_enabled': autoAssignEnabled,
      }),
    );
    _throwOnError(response);
    return SessionPreset.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteSessionPreset(int presetId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/session-presets/$presetId'),
      headers: _headers,
    );
    _throwOnError(response);
  }

  Future<SessionState> manualAssign(
    int sessionId,
    int courtId,
    List<int> playerIds,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/courts/$courtId/assign',
      ),
      headers: _headers,
      body: jsonEncode({'player_ids': playerIds}),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<({SessionReport report, SessionState state})> endSession(
    int sessionId,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/end'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      report: SessionReport.fromJson(body['report'] as Map<String, dynamic>),
      state: SessionState.fromJson(body['state'] as Map<String, dynamic>),
    );
  }

  Future<SessionReport> getReport(int sessionId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/report'),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionReport.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, int>> getCalendarMarkers({
    required int year,
    required int month,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/calendar?year=$year&month=$month',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseIntMap(body['markers']);
  }

  Map<String, int> _parseIntMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toInt() : int.tryParse('$value') ?? 0,
      ),
    );
  }

  Future<List<SessionHistorySummary>> getSessionsOnDate(String date) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/history?date=$date'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['sessions'] as List<dynamic>? ?? [])
        .map((e) => SessionHistorySummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionHistoryDetail> getSessionHistory(int sessionId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/history'),
      headers: _headers,
    );
    _throwOnError(response);
    return SessionHistoryDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<({List<ClubPlayerInfo> players, int? activeSessionId})> getClubPlayers({
    String? search,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/players').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      players: (body['players'] as List<dynamic>? ?? [])
          .map((e) => ClubPlayerInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeSessionId: body['activeSessionId'] as int?,
    );
  }

  Future<ClubPlayerInfo> registerClubPlayer(
    String name, {
    required String skillLevel,
    required String gender,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/players'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'skill_level': skillLevel,
        'gender': gender,
      }),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ClubPlayerInfo.fromJson(body['player'] as Map<String, dynamic>);
  }

  Future<void> deleteClubPlayer(int clubPlayerId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/players/$clubPlayerId'),
      headers: _headers,
    );
    _throwOnError(response);
  }

  Future<SessionState> joinSession(
    int clubPlayerId, {
    String? skillLevel,
    String? gender,
    String? paymentAction,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/session/join'),
      headers: _headers,
      body: jsonEncode({
        'club_player_id': clubPlayerId,
        if (skillLevel != null) 'skill_level': skillLevel,
        if (gender != null) 'gender': gender,
        if (paymentAction != null) 'payment_action': paymentAction,
      }),
    );
    if (response.statusCode == 202) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return SessionState.fromJson(body['state'] as Map<String, dynamic>);
    }
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionState.fromJson(body['state'] as Map<String, dynamic>);
  }

  Future<SessionState> removeFromSession({int? clubPlayerId}) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/session/remove'),
      headers: _headers,
      body: jsonEncode({
        if (clubPlayerId != null) 'club_player_id': clubPlayerId,
      }),
    );
    _throwOnError(response);
    return SessionState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<LeaderboardEntry>> getAllTimeLeaderboard() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/leaderboard/all-time'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['leaderboard'] as List<dynamic>? ?? [])
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({int sessionId, String sessionName, List<LeaderboardEntry> entries})>
      getSessionLeaderboard(int sessionId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/leaderboard/session/$sessionId'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      sessionId: body['sessionId'] as int,
      sessionName: body['sessionName'] as String,
      entries: (body['leaderboard'] as List<dynamic>? ?? [])
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<({String label, List<LeaderboardEntry> entries})>
      getMonthlyLeaderboard({int? year, int? month}) async {
    final query = <String, String>{};
    if (year != null) query['year'] = '$year';
    if (month != null) query['month'] = '$month';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/leaderboard/monthly')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      label: body['label'] as String? ?? 'This Month',
      entries: (body['leaderboard'] as List<dynamic>? ?? [])
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<({String label, List<LeaderboardEntry> entries})> getSeasonLeaderboard({
    int? year,
  }) async {
    final uri = year == null
        ? Uri.parse('${AppConfig.apiBaseUrl}/leaderboard/season')
        : Uri.parse(
            '${AppConfig.apiBaseUrl}/leaderboard/season?year=$year',
          );
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      label: body['label'] as String? ?? 'Season',
      entries: (body['leaderboard'] as List<dynamic>? ?? [])
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<PlayerProfileDetail> getPlayerProfile(int clubPlayerId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/players/$clubPlayerId'),
      headers: _headers,
    );
    _throwOnError(response);
    return PlayerProfileDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<({String filename, String content})> exportSessionReport(
    int sessionId,
  ) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/sessions/$sessionId/export'),
      headers: {
        if (_resolvedAdminPin.isNotEmpty) 'X-Admin-Pin': _resolvedAdminPin,
      },
    );
    _throwOnError(response);

    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'session-$sessionId-report.csv';

    return (filename: filename, content: response.body);
  }

  Future<SessionState> markRegistrationPaid(
    int sessionId,
    int clubPlayerId, {
    String method = 'cash',
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/registrations/$clubPlayerId/mark-paid',
      ),
      headers: _headers,
      body: jsonEncode({'method': method}),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionState.fromJson(body['state'] as Map<String, dynamic>);
  }

  Future<SessionState> markRegistrationWaived(
    int sessionId,
    int clubPlayerId, {
    String? notes,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/sessions/$sessionId/registrations/$clubPlayerId/mark-waived',
      ),
      headers: _headers,
      body: jsonEncode({
        if (notes != null) 'notes': notes,
      }),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SessionState.fromJson(body['state'] as Map<String, dynamic>);
  }

  Future<RevenueSummary> getRevenue({
    String? from,
    String? to,
    int? sessionId,
  }) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    if (sessionId != null) query['session_id'] = '$sessionId';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/revenue')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    return RevenueSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentListResponse> listTournaments() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments'),
      headers: _headers,
    );
    _throwOnError(response);
    return TournamentListResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> getTournament(int tournamentId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId'),
      headers: _headers,
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState?> getActiveTournament() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/active'),
      headers: _headers,
    );
    if (response.statusCode == 404) {
      return null;
    }
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> createTournament({
    required String name,
    required int groupCount,
    required List<String> categories,
    int courtCount = 4,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'group_count': groupCount,
        'court_count': courtCount,
        'categories': categories,
      }),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> updateTournament(
    int tournamentId, {
    String? name,
    int? groupCount,
    List<String>? categories,
    int? courtCount,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (groupCount != null) 'group_count': groupCount,
        if (categories != null) 'categories': categories,
        if (courtCount != null) 'court_count': courtCount,
      }),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> startTournament(int tournamentId) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId/start'),
      headers: _headers,
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> registerTournamentTeam(
    int tournamentId,
    String categoryKey, {
    List<int>? playerIds,
    List<String>? playerNames,
    List<String>? genders,
  }) async {
    final body = <String, dynamic>{};
    if (playerNames != null) {
      body['player_names'] = playerNames;
      body['genders'] = genders ?? [];
    } else {
      body['player_ids'] = playerIds ?? [];
    }

    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/categories/${Uri.encodeComponent(categoryKey)}/teams',
      ),
      headers: _headers,
      body: jsonEncode(body),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<({TournamentState state, List<Map<String, dynamic>> pairs})>
      drawLotsTournamentTeams(
    int tournamentId,
    String categoryKey, {
    required List<String> playerNames,
    List<String>? genders,
  }) async {
    final body = <String, dynamic>{
      'player_names': playerNames,
      if (genders != null) 'genders': genders,
    };

    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/categories/${Uri.encodeComponent(categoryKey)}/draw-lots',
      ),
      headers: _headers,
      body: jsonEncode(body),
    );
    _throwOnError(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      state: TournamentState.fromJson(decoded['state'] as Map<String, dynamic>),
      pairs: (decoded['pairs'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  Future<void> deleteTournament(int tournamentId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId'),
      headers: _headers,
    );
    _throwOnError(response);
  }

  Future<TournamentState> removeTournamentTeam(
    int tournamentId,
    int teamId,
  ) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/tournaments/$tournamentId/teams/$teamId'),
      headers: _headers,
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> updateTournamentPlayerName(
    int tournamentId,
    int clubPlayerId,
    String name,
  ) async {
    final response = await _client.patch(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/players/$clubPlayerId',
      ),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> scoreTournamentMatch(
    int tournamentId,
    int matchId, {
    required int scoreA,
    required int scoreB,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/matches/$matchId/score',
      ),
      headers: _headers,
      body: jsonEncode({
        'score_a': scoreA,
        'score_b': scoreB,
      }),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> activateTournamentCourtMatch(
    int tournamentId,
    int matchId,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/matches/$matchId/activate-court',
      ),
      headers: _headers,
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> assignTournamentCourtMatch(
    int tournamentId,
    int matchId, {
    required int courtNumber,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/matches/$matchId/assign-court',
      ),
      headers: _headers,
      body: jsonEncode({'court_number': courtNumber}),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TournamentState> replaceTournamentCourtMatch(
    int tournamentId,
    int matchId, {
    required int courtNumber,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/tournaments/$tournamentId/matches/$matchId/replace-court',
      ),
      headers: _headers,
      body: jsonEncode({'court_number': courtNumber}),
    );
    _throwOnError(response);
    return TournamentState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['message'] != null) message = body['message'] as String;
      final detail = body['error'];
      if (detail is String &&
          detail.isNotEmpty &&
          detail != message &&
          !message.contains(detail)) {
        message = '$message: $detail';
      }
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }
}
