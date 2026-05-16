import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trend_item.dart';
import '../models/topic_preset.dart';
import '../services/youtube_service.dart';
import '../services/reddit_service.dart';
import '../services/news_service.dart';
import '../services/github_service.dart';
import '../services/tech_service.dart';
import '../services/trend_engine.dart';
import '../services/feed_cache_service.dart';
import 'filter_provider.dart';
import '../models/filter_state.dart';

// Words that must never appear as a cluster banner topic label.
// Keep in sync with the broadcast-noise section of TrendEngine._stopWords.
const _bannerNoiseWords = {
  'live', 'breaking', 'update', 'updates', 'watch', 'video', 'exclusive',
  'says', 'said', 'say', 'report', 'reports', 'reported',
  'warn', 'warns', 'warned', 'calls', 'hits', 'reveals', 'revealed',
  'reveal', 'shows', 'read', 'here', 'know', 'inside', 'ahead', 'back',
  'claim', 'claims', 'claimed', 'joins', 'join', 'seen', 'slams', 'slam',
  'blasts', 'blast', 'major', 'massive', 'huge', 'historic', 'dramatic',
  'shocking', 'stunning', 'urgent', 'critical', 'key', 'special', 'viral',
  'bold', 'rare', 'giant', 'biggest', 'largest', 'worst', 'greatest',
  'makes', 'takes', 'gets', 'gives', 'faces', 'needs', 'wants', 'plans',
  'seeks', 'asks', 'tells', 'finds', 'turns', 'runs', 'wins', 'loses',
  'beats', 'leads', 'ends', 'begins', 'starts', 'comes', 'goes',
  'today', 'tonight', 'soon', 'already', 'still', 'again', 'ever', 'once',
  'daily', 'weekly', 'amid', 'recap', 'roundup', 'explainer', 'analysis',
  'opinion', 'review', 'interview', 'podcast', 'episode', 'series', 'guide',
  'preview', 'edition', 'column', 'feature', 'story', 'piece', 'coverage',
  'share', 'shares', 'follow', 'subscribe', 'trending', 'popular',
  'despite', 'following', 'including', 'between', 'against', 'during',
  'regarding', 'across', 'without', 'within', 'under', 'through',
};

// ── Cluster Alert Model ──────────────────────────────────────────────────────

class ClusterAlert {
  final String topic;
  final int sourceCount;
  final int itemCount;
  final String clusterId;

  const ClusterAlert({
    required this.topic,
    required this.sourceCount,
    required this.itemCount,
    required this.clusterId,
  });
}

// ── Service Providers ────────────────────────────────────────────────────────

final youTubeServiceProvider = Provider((_) => YouTubeService());
final redditServiceProvider = Provider((_) => RedditService());
final newsServiceProvider = Provider((_) => NewsService());
final gitHubServiceProvider = Provider((_) => GitHubService());
final techServiceProvider = Provider((_) => TechService());
final trendEngineProvider = Provider((_) => TrendEngine());
final feedCacheServiceProvider = Provider((_) => FeedCacheService());

// Active source filter — null means "all"
final sourceFilterProvider = StateProvider<TrendSource?>((ref) => null);

/// How many items the Trending feed currently shows. Incremented by
/// [feedPageStep] each time the user taps "Load More".
const feedPageStep = 20;
const feedPageInitial = 30;
final feedDisplayCountProvider = StateProvider<int>((ref) => feedPageInitial);

/// Active topic preset — null means "no preset, use plain filterProvider".
final topicPresetProvider = StateProvider<TopicPreset?>((ref) => null);

/// The effective FilterState driving the feed.
final activeFeedFiltersProvider = Provider<FilterState>((ref) {
  final base = ref.watch(filterProvider);
  final preset = ref.watch(topicPresetProvider);
  return preset?.applyTo(base) ?? base;
});

final feedProvider = FutureProvider<List<TrendItem>>((ref) async {
  final filters = ref.watch(activeFeedFiltersProvider);
  final yt = ref.watch(youTubeServiceProvider);
  final reddit = ref.watch(redditServiceProvider);
  final news = ref.watch(newsServiceProvider);
  final github = ref.watch(gitHubServiceProvider);
  final tech = ref.watch(techServiceProvider);
  final engine = ref.watch(trendEngineProvider);
  final cache = ref.watch(feedCacheServiceProvider);

  Object? lastError;

  Future<List<TrendItem>> safely(Future<List<TrendItem>> f) =>
      f.catchError((e) {
        lastError = e;
        return <TrendItem>[];
      });

  try {
    final results = await Future.wait([
      if (filters.youtubeEnabled) safely(yt.fetchTrending(filters: filters))
      else Future.value(<TrendItem>[]),
      
      if (filters.redditEnabled) safely(reddit.fetchTrending(filters: filters))
      else Future.value(<TrendItem>[]),
      
      if (filters.newsEnabled) safely(news.fetchTrending(filters: filters))
      else Future.value(<TrendItem>[]),
      
      if (filters.githubEnabled) safely(github.fetchTrending(filters: filters))
      else Future.value(<TrendItem>[]),
      
      if (filters.hackerNewsEnabled) safely(tech.fetchHackerNews())
      else Future.value(<TrendItem>[]),
      
      if (filters.productHuntEnabled) safely(tech.fetchProductHunt())
      else Future.value(<TrendItem>[]),
      
      if (filters.devToEnabled) safely(tech.fetchDevTo())
      else Future.value(<TrendItem>[]),
    ]);

    final combined = engine.process(
      youtubeItems: results[0],
      redditItems: results[1],
      newsItems: results[2],
      githubItems: results[3],
      hnItems: results[4],
      phItems: results[5],
      devToItems: results[6],
    );

    if (combined.isEmpty && lastError != null) {
      final cached = await cache.load();
      if (cached != null && cached.isNotEmpty) return cached;
      throw lastError!;
    }

    final ranked = combined.where((item) {
      if (item.source == TrendSource.youtube && filters.minYoutubeViews > 0) {
        return (item.score ?? 0) >= filters.minYoutubeViews;
      }
      if (item.source == TrendSource.reddit && filters.minRedditUpvotes > 0) {
        return (item.score ?? 0) >= filters.minRedditUpvotes;
      }
      if (item.source == TrendSource.github && filters.minGithubStars > 0) {
        return (item.score ?? 0) >= filters.minGithubStars;
      }
      return true;
    }).toList();

    if (filters.sortOrder == SortOrder.date) {
      ranked.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }

    await cache.save(ranked);
    return ranked;
  } catch (_) {
    final cached = await cache.load();
    if (cached != null && cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Builds clusterId → items map once so downstream providers don't re-iterate.
final _clusteredItemsProvider = Provider<Map<String, List<TrendItem>>>((ref) {
  final items = ref.watch(feedProvider).valueOrNull;
  if (items == null || items.isEmpty) return const {};
  final map = <String, List<TrendItem>>{};
  for (final item in items) {
    if (item.clusterId == null) continue;
    map.putIfAbsent(item.clusterId!, () => []).add(item);
  }
  return map;
});

/// Returns the most cross-platform cluster (≥2 distinct sources), or null.
final clusterAlertProvider = Provider<ClusterAlert?>((ref) {
  final clusterItems = ref.watch(_clusteredItemsProvider);
  if (clusterItems.isEmpty) return null;

  // When India mode is active, "india"/"indian" saturates every headline —
  // suppress them so the banner shows WHAT is trending, not WHERE.
  final filters = ref.watch(activeFeedFiltersProvider);
  final regionNoise = filters.region == FeedRegion.india
      ? const {'india', 'indian', 'indias'}
      : const <String>{};
  final effectiveNoise = {..._bannerNoiseWords, ...regionNoise};

  final clusterSources = <String, Set<TrendSource>>{};
  for (final entry in clusterItems.entries) {
    for (final item in entry.value) {
      clusterSources.putIfAbsent(entry.key, () => {}).add(item.source);
    }
  }

  String? bestId;
  int bestCount = 1; // minimum threshold: 2 sources
  for (final entry in clusterSources.entries) {
    if (entry.value.length > bestCount) {
      bestCount = entry.value.length;
      bestId = entry.key;
    }
  }

  if (bestId == null) return null;

  final clusterList = clusterItems[bestId]!;

  // Find tags that appear in items from multiple distinct sources —
  // those are the genuinely cross-platform trending keywords.
  final tagSources = <String, Set<TrendSource>>{};
  for (final item in clusterList) {
    for (final tag in item.tags) {
      tagSources.putIfAbsent(tag, () => {}).add(item.source);
    }
  }

  // Prefer a tag seen across the most sources; break ties by total frequency.
  final tagFreq = <String, int>{};
  for (final item in clusterList) {
    for (final tag in item.tags) {
      tagFreq[tag] = (tagFreq[tag] ?? 0) + 1;
    }
  }

  String topic;
  final crossPlatformTags = tagSources.entries
      .where((e) => e.value.length > 1 && !effectiveNoise.contains(e.key))
      .toList()
    ..sort((a, b) {
      final srcCmp = b.value.length.compareTo(a.value.length);
      if (srcCmp != 0) return srcCmp;
      return (tagFreq[b.key] ?? 0).compareTo(tagFreq[a.key] ?? 0);
    });

  if (crossPlatformTags.isNotEmpty) {
    topic = crossPlatformTags.first.key;
  } else if (tagFreq.isNotEmpty) {
    // All items from one source — pick most frequent non-noise tag
    final cleanedTags = tagFreq.entries
        .where((e) => !effectiveNoise.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topic = cleanedTags.isNotEmpty
        ? cleanedTags.first.key
        : (tagFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
  } else {
    topic = clusterList
        .reduce((a, b) => a.normalizedScore >= b.normalizedScore ? a : b)
        .title
        .split(' ')
        .take(3)
        .join(' ');
  }

  return ClusterAlert(
    topic: topic,
    sourceCount: bestCount,
    itemCount: clusterItems[bestId]!.length,
    clusterId: bestId,
  );
});

// ── Signal Radar ─────────────────────────────────────────────────────────────

class RadarCluster {
  final String id;
  final String topic;
  final List<TrendItem> items; // sorted by normalizedScore desc
  final Set<TrendSource> sources;
  final TrendSentiment dominantSentiment;
  final String momentum; // of the top item

  const RadarCluster({
    required this.id,
    required this.topic,
    required this.items,
    required this.sources,
    required this.dominantSentiment,
    required this.momentum,
  });

  int get itemCount => items.length;
  int get sourceCount => sources.length;
  TrendItem get topItem => items.first;
}

/// Top clusters for the Signal Radar, ranked by cross-platform coverage.
/// Returns up to 6 clusters with ≥ 2 items.
final radarClustersProvider = Provider<List<RadarCluster>>((ref) {
  final clusterMap = ref.watch(_clusteredItemsProvider);
  if (clusterMap.isEmpty) return [];

  final clusters = <RadarCluster>[];

  for (final entry in clusterMap.entries) {
    if (entry.value.length < 2) continue;

    final clusterItems = [...entry.value]
      ..sort((a, b) => b.normalizedScore.compareTo(a.normalizedScore));

    // Pick best topic tag — most frequent non-noise tag across the cluster
    final tagFreq = <String, int>{};
    for (final item in clusterItems) {
      for (final tag in item.tags) {
        if (!_bannerNoiseWords.contains(tag) && tag.length > 3) {
          tagFreq[tag] = (tagFreq[tag] ?? 0) + 1;
        }
      }
    }
    String topic = '';
    if (tagFreq.isNotEmpty) {
      final sorted = tagFreq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topic = sorted.first.key;
    }
    if (topic.isEmpty) {
      topic = clusterItems.first.title.split(' ').take(3).join(' ');
    }

    // Dominant sentiment by vote
    final sentCount = <TrendSentiment, int>{};
    for (final item in clusterItems) {
      sentCount[item.sentiment] = (sentCount[item.sentiment] ?? 0) + 1;
    }
    final dominantSentiment = sentCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    clusters.add(RadarCluster(
      id: entry.key,
      topic: topic,
      items: clusterItems,
      sources: clusterItems.map((i) => i.source).toSet(),
      dominantSentiment: dominantSentiment,
      momentum: clusterItems.first.momentum,
    ));
  }

  // Sort: most cross-platform first, then by item count
  clusters.sort((a, b) {
    final srcCmp = b.sourceCount.compareTo(a.sourceCount);
    if (srcCmp != 0) return srcCmp;
    return b.itemCount.compareTo(a.itemCount);
  });

  return clusters.take(6).toList();
});
