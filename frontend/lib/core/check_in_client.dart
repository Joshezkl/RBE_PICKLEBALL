import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'config.dart';
import 'models.dart';

class CheckInClient {
  CheckInClient({http.Client? client, required this.token})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Check-In-Token': token,
      };

  Future<CheckInSessionInfo> getSession() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/check-in/session'),
      headers: _headers,
    );
    _throwOnError(response);
    return CheckInSessionInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ClubPlayerInfo>> searchPlayers(String query) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/check-in/players').replace(
      queryParameters: query.isEmpty ? null : {'search': query},
    );
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['players'] as List<dynamic>? ?? [])
        .map((e) => ClubPlayerInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SessionRosterPlayer>> searchSessionRoster(String query) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/check-in/session-players')
        .replace(
      queryParameters: query.isEmpty ? null : {'search': query},
    );
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['players'] as List<dynamic>? ?? [])
        .map((e) => SessionRosterPlayer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({ClubPlayerInfo player, CheckInPlayerStatus status})> register({
    required String name,
    required String skillLevel,
    required String gender,
    bool isGuest = false,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/check-in/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'skill_level': skillLevel,
        'gender': gender,
        'is_guest': isGuest,
        'join_session': true,
      }),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      player: ClubPlayerInfo.fromJson(body['player'] as Map<String, dynamic>),
      status: CheckInPlayerStatus.fromJson(
        body['status'] as Map<String, dynamic>? ?? {'status': 'not_joined'},
      ),
    );
  }

  Future<CheckInPlayerStatus> join(int clubPlayerId) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/check-in/join'),
      headers: _headers,
      body: jsonEncode({'club_player_id': clubPlayerId}),
    );
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 402) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return CheckInPlayerStatus.fromJson(
        body['status'] as Map<String, dynamic>? ?? {},
      );
    }
    _throwOnError(response);
    throw ApiException('Check-in failed');
  }

  Future<CheckInPlayerStatus> getStatus({
    int? clubPlayerId,
    int? playerId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/check-in/status').replace(
      queryParameters: {
        if (clubPlayerId != null) 'club_player_id': '$clubPlayerId',
        if (playerId != null) 'player_id': '$playerId',
      },
    );
    final response = await _client.get(uri, headers: _headers);
    _throwOnError(response);
    return CheckInPlayerStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CheckInPlayerStatus> stepOut({
    int? clubPlayerId,
    int? playerId,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/check-in/step-out'),
      headers: _headers,
      body: jsonEncode({
        if (clubPlayerId != null) 'club_player_id': clubPlayerId,
        if (playerId != null) 'player_id': playerId,
      }),
    );
    _throwOnError(response);
    return CheckInPlayerStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CheckInPlayerStatus> stepBack({
    int? clubPlayerId,
    int? playerId,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/check-in/step-back'),
      headers: _headers,
      body: jsonEncode({
        if (clubPlayerId != null) 'club_player_id': clubPlayerId,
        if (playerId != null) 'player_id': playerId,
      }),
    );
    _throwOnError(response);
    return CheckInPlayerStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['message'] is String) message = body['message'] as String;
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }
}
