import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trend_item.dart';

/// Persists the last successful feed to SharedPreferences so the app can
/// show content when the network is unavailable.
class FeedCacheService {
  static const _cacheKey = 'feed_cache_v1';

  /// Returns cached items if present, regardless of age.
  /// Returns null only when no cache exists at all.
  Future<List<TrendItem>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['items'] as List<dynamic>;
      return list
          .map((e) => TrendItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Saves items along with the current timestamp.
  Future<void> save(List<TrendItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'items': items.map((e) => e.toMap()).toList(),
      }),
    );
  }

  /// Returns when the cache was last written, or null if empty.
  Future<DateTime?> lastSavedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.parse(map['savedAt'] as String);
    } catch (_) {
      return null;
    }
  }
}
