import 'package:flutter/foundation.dart';

/// Strips query params from a hash-route name (e.g. `/check-in?token=abc` → `/check-in`).
String normalizeRouteName(String? name, {String fallback = '/admin'}) {
  if (name == null || name.isEmpty) return fallback;
  final path = name.startsWith('/') ? name : '/$name';
  return path.split('?').first;
}

/// Reads the initial route from the browser hash fragment, if present.
String resolveInitialRoute({String fallback = '/admin'}) {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return fallback;
  return normalizeRouteName(fragment, fallback: fallback);
}

/// Extracts the check-in token from the current URL (hash or query).
String? checkInTokenFromUri([Uri? uri]) {
  final base = uri ?? Uri.base;
  final fragment = base.fragment;
  if (fragment.contains('token=')) {
    final query = fragment.contains('?')
        ? fragment.split('?').last
        : fragment;
    return Uri.splitQueryString(query)['token'];
  }
  return base.queryParameters['token'];
}

Map<String, String> _fragmentQueryParams([Uri? uri]) {
  final base = uri ?? Uri.base;
  final fragment = base.fragment;
  if (!fragment.contains('?')) return {};
  final query = fragment.contains('?')
      ? fragment.split('?').last
      : fragment;
  return Uri.splitQueryString(query);
}

/// Extracts club_player_id from the current URL hash fragment.
int? clubPlayerIdFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['club_player_id'];
  return value == null ? null : int.tryParse(value);
}

/// Extracts player_id from the current URL hash fragment.
int? playerIdFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['player_id'];
  return value == null ? null : int.tryParse(value);
}

/// Builds the player-facing check-in URL for QR codes.
String buildCheckInUrl(String token) {
  return _buildHashUrl('/check-in', {'token': token});
}

/// Builds the personal queue status URL (optionally pre-linked to a player).
String buildQueueStatusUrl(
  String token, {
  int? clubPlayerId,
  int? playerId,
}) {
  return _buildHashUrl('/queue-status', {
    'token': token,
    if (clubPlayerId != null) 'club_player_id': '$clubPlayerId',
    if (playerId != null) 'player_id': '$playerId',
  });
}

String _buildHashUrl(String route, Map<String, String> params) {
  final base = Uri.base;
  final port = base.hasPort ? ':${base.port}' : '';
  final origin = '${base.scheme}://${base.host}$port';
  final path = base.path.endsWith('/') ? base.path : '${base.path}/';
  final query = params.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '$origin$path#$route?$query';
}

void copyCheckInUrl(String token) {
  // Clipboard handled in widget layer; helper for tests/logging.
  if (kDebugMode) {
    // ignore: avoid_print
    print('Check-in URL: ${buildCheckInUrl(token)}');
  }
}
