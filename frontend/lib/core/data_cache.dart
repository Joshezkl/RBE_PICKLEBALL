/// Simple in-memory TTL cache for API responses and screen data.
///
/// Keeps recently-fetched payloads alive across route changes so switching
/// admin screens does not re-hit the network for the same data.
class DataCache {
  DataCache._();

  static final Map<String, _CacheEntry> _entries = {};

  /// Returns a cached value when present and younger than [ttl].
  static T? get<T>(String key, Duration ttl) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  static void set<T>(String key, T value) {
    _entries[key] = _CacheEntry(value, DateTime.now());
  }

  /// Drop every entry whose key starts with [prefix].
  static void invalidatePrefix(String prefix) {
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void invalidate(String key) => _entries.remove(key);

  static void clear() => _entries.clear();
}

class _CacheEntry {
  _CacheEntry(this.value, this.storedAt);

  final Object? value;
  final DateTime storedAt;
}
