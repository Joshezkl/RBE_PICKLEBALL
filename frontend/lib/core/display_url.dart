/// Court number from hash route query, e.g. `#/court?n=3`.
int? courtNumberFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['n'] ?? _fragmentQueryParams(uri)['court'];
  return value == null ? null : int.tryParse(value);
}

bool displayAnnounceEnabledFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['announce'];
  if (value == null) return true;
  return value != '0' && value.toLowerCase() != 'false';
}

bool displaySoundsEnabledFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['sounds'];
  if (value == null) return true;
  return value != '0' && value.toLowerCase() != 'false';
}

bool tournamentAnnouncementsEnabledFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['announce'];
  if (value == null) return true;
  return value != '0' && value.toLowerCase() != 'false';
}

bool tournamentCelebrationsEnabledFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['celebrate'];
  if (value == null) return true;
  return value != '0' && value.toLowerCase() != 'false';
}

bool tournamentVoiceEnabledFromUri([Uri? uri]) {
  final value = _fragmentQueryParams(uri)['voice'];
  if (value == null) return true;
  return value != '0' && value.toLowerCase() != 'false';
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
