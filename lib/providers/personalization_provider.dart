import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trend_item.dart';
import '../services/personalization_engine.dart';
import 'feedback_provider.dart';
import 'feed_provider.dart';
import 'personalization_prefs_provider.dart';
import 'user_provider.dart';

final personalizationEngineProvider =
    Provider((_) => PersonalizationEngine());

final personalizationProfileProvider =
    FutureProvider<PersonalizationProfile>((ref) async {
  final engine = ref.watch(personalizationEngineProvider);
  final feedbackState = ref.watch(feedbackProvider);
  await ref.watch(feedbackLoaderProvider.future);
  final bookmarks = await ref.watch(bookmarksProvider.future);
  final searchHistory = await ref.watch(searchHistoryProvider.future);

  final bookmarkItems = <TrendItem>[];
  for (final bookmark in bookmarks) {
    try {
      bookmarkItems.add(TrendItem.fromMap(bookmark));
    } catch (_) {}
  }

  final queries = searchHistory
      .map((entry) => entry['query'] as String? ?? '')
      .where((query) => query.trim().isNotEmpty)
      .toList();

  return engine.buildProfile(
    feedbackEntries: feedbackState.values.toList(),
    bookmarks: bookmarkItems,
    searchQueries: queries,
  );
});

final personalizedFeedProvider = Provider<AsyncValue<List<TrendItem>>>((ref) {
  final feedAsync = ref.watch(feedProvider);
  final prefs = ref.watch(personalizationPrefsProvider);

  // Master off → pure trending order, no reranking at all
  if (!prefs.enabled) return feedAsync;

  final profile = ref.watch(personalizationProfileProvider).valueOrNull;
  final engine = ref.watch(personalizationEngineProvider);

  // Build an augmented profile that merges implicit signals with explicit
  // interests the user pinned in the profile screen.
  final effectiveProfile = profile == null
      ? _profileFromPrefs(prefs)
      : _mergeExplicitInterests(profile, prefs.interests);

  if (!effectiveProfile.hasSignals) return feedAsync;

  return feedAsync.whenData((items) => engine.rerank(items, effectiveProfile));
});

/// Creates a minimal profile from explicit interests only (no implicit signals yet).
PersonalizationProfile _profileFromPrefs(PersonalizationPrefs prefs) {
  if (prefs.interests.isEmpty) return const PersonalizationProfile();
  return PersonalizationProfile(
    keywordAffinity: {
      for (final topic in prefs.interests) topic: 4.0,
    },
  );
}

/// Merges explicit interests (strong weight = 4.0) into an existing profile.
/// Existing implicit signals are kept unchanged.
PersonalizationProfile _mergeExplicitInterests(
  PersonalizationProfile base,
  List<String> interests,
) {
  if (interests.isEmpty) return base;
  final merged = Map<String, double>.from(base.keywordAffinity);
  for (final topic in interests) {
    // Explicit interest always wins — set to at least 4.0
    merged[topic] = (merged[topic] ?? 0) < 4.0 ? 4.0 : merged[topic]!;
  }
  return PersonalizationProfile(
    sourceAffinity: base.sourceAffinity,
    keywordAffinity: merged,
    clusterAffinity: base.clusterAffinity,
    sourceNameAffinity: base.sourceNameAffinity,
    authorAffinity: base.authorAffinity,
    likedItemIds: base.likedItemIds,
    dislikedItemIds: base.dislikedItemIds,
  );
}
