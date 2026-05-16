import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trend_item.dart';
import 'feed_provider.dart';
import 'filter_provider.dart';

// Holds the current search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Per-source search providers — each tab in Search screen watches its own.
// Results are passed through TrendEngine so decay, momentum, and tags apply
// even in single-source views.
final youtubeSearchProvider =
    FutureProvider.autoDispose<List<TrendItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final filters = ref.watch(filterProvider);
  final engine = ref.watch(trendEngineProvider);
  final items =
      await ref.watch(youTubeServiceProvider).search(query, filters: filters);
  return engine.process(
      youtubeItems: items, redditItems: [], newsItems: [], githubItems: []);
});

final redditSearchProvider =
    FutureProvider.autoDispose<List<TrendItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final filters = ref.watch(filterProvider);
  final engine = ref.watch(trendEngineProvider);
  final items =
      await ref.watch(redditServiceProvider).search(query, filters: filters);
  return engine.process(
      youtubeItems: [], redditItems: items, newsItems: [], githubItems: []);
});

final newsSearchProvider =
    FutureProvider.autoDispose<List<TrendItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final filters = ref.watch(filterProvider);
  final engine = ref.watch(trendEngineProvider);
  final items =
      await ref.watch(newsServiceProvider).search(query, filters: filters);
  return engine.process(
      youtubeItems: [], redditItems: [], newsItems: items, githubItems: []);
});

final githubSearchProvider =
    FutureProvider.autoDispose<List<TrendItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final filters = ref.watch(filterProvider);
  final engine = ref.watch(trendEngineProvider);
  final items =
      await ref.watch(gitHubServiceProvider).search(query, filters: filters);
  return engine.process(
      youtubeItems: [], redditItems: [], newsItems: [], githubItems: items);
});

/// Unified cross-source search — results are ranked and clustered by
/// TrendEngine using the same scoring pipeline as the main feed.
final unifiedSearchProvider =
    FutureProvider.autoDispose<List<TrendItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final filters = ref.watch(filterProvider);
  final engine = ref.watch(trendEngineProvider);

  Object? lastError;

  Future<List<TrendItem>> safely(Future<List<TrendItem>> f) =>
      f.catchError((e) {
        lastError = e;
        return <TrendItem>[];
      });

  final results = await Future.wait([
    if (filters.youtubeEnabled)
      safely(ref.watch(youTubeServiceProvider).search(query, filters: filters))
    else
      Future.value(<TrendItem>[]),
    if (filters.redditEnabled)
      safely(ref.watch(redditServiceProvider).search(query, filters: filters))
    else
      Future.value(<TrendItem>[]),
    if (filters.newsEnabled)
      safely(ref.watch(newsServiceProvider).search(query, filters: filters))
    else
      Future.value(<TrendItem>[]),
    if (filters.githubEnabled)
      safely(ref.watch(gitHubServiceProvider).search(query, filters: filters))
    else
      Future.value(<TrendItem>[]),
  ]);

  final ranked = engine.process(
    youtubeItems: results[0],
    redditItems: results[1],
    newsItems: results[2],
    githubItems: results[3],
  );

  if (ranked.isEmpty && lastError != null) throw lastError!;
  return ranked;
});
