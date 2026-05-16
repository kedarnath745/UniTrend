import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trend_item.dart';
import 'feed_provider.dart';

class WatchlistNotifier extends StateNotifier<List<String>> {
  static const _prefsKey = 'watchlist_keywords';

  WatchlistNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? [];
  }

  Future<void> follow(String keyword) async {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty || state.contains(kw)) return;
    state = [...state, kw];
    await _save();
  }

  Future<void> unfollow(String keyword) async {
    state = state.where((k) => k != keyword).toList();
    await _save();
  }

  bool isFollowing(String keyword) =>
      state.contains(keyword.trim().toLowerCase());

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<String>>(
  (_) => WatchlistNotifier(),
);

/// For each followed keyword, returns matched TrendItems from the live feed.
/// Applies a +25% score boost to matched items.
/// Map key = keyword (lowercase), value = matching items sorted by boosted score.
/// Notification side-effects are handled in MainShell via ref.listen.
final watchlistFeedProvider =
    Provider<AsyncValue<Map<String, List<TrendItem>>>>((ref) {
  final feedAsync = ref.watch(feedProvider);
  final keywords = ref.watch(watchlistProvider);

  if (keywords.isEmpty) return const AsyncValue.data({});

  return feedAsync.whenData((items) {
    final result = <String, List<TrendItem>>{};
    for (final kw in keywords) {
      final matched = items.where((i) {
        final title = i.title.toLowerCase();
        final desc = i.description?.toLowerCase() ?? '';
        return title.contains(kw) ||
            desc.contains(kw) ||
            i.tags.any((t) => t.toLowerCase().contains(kw));
      }).map((i) {
        // +25% score boost for watchlist matches
        final boosted = i.score != null
            ? i.copyWith(score: (i.score! * 1.25).round())
            : i;
        return boosted;
      }).toList()
        ..sort((a, b) =>
            b.normalizedScore.compareTo(a.normalizedScore));

      result[kw] = matched;
    }
    return result;
  });
});
