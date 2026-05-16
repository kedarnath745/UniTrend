import 'dart:math';
import '../models/trend_item.dart';
import 'sentiment_engine.dart';

/// Processes raw feed items from all sources through normalization,
/// recency decay, tag extraction, clustering, and momentum scoring.
class TrendEngine {
  // Per-source score multipliers — high-intent sources rank higher
  // Tech-niche sources (HN, Product Hunt, Dev.to) are weighted lower
  // to prevent them from drowning out mainstream news and videos.
  static const _sourceWeights = {
    TrendSource.github: 1.2,
    TrendSource.reddit: 1.1,
    TrendSource.news: 1.0,
    TrendSource.youtube: 0.8,
    TrendSource.productHunt: 0.7,
    TrendSource.hackerNews: 0.5,
    TrendSource.devTo: 0.5,
  };

  // Words excluded from tag extraction and cluster matching
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been',
    'has', 'have', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'this', 'that', 'these', 'those', 'it', 'its',
    'as', 'up', 'out', 'about', 'into', 'than', 'then', 'so', 'if', 'how',
    'what', 'when', 'where', 'why', 'who', 'which', 'not', 'no', 'new',
    'get', 'just', 'can', 'all', 'your', 'my', 'we', 'you', 'he', 'she',
    'they', 'their', 'our', 'his', 'her', 'more', 'after', 'over', 'use',
    'also', 'some', 'such', 'two', 'one', 'now', 'like',
    // Generic tech/content words that add no signal
    'built', 'build', 'make', 'made', 'open', 'source', 'free', 'tool',
    'best', 'fast', 'simple', 'easy', 'next', 'work', 'list', 'good',
    'based', 'using', 'used', 'code', 'data', 'high', 'full', 'real',
    'top', 'week', 'post', 'posts', 'featured', 'latest', 'awesome',
    'repo', 'library', 'app', 'apps', 'support', 'help', 'type', 'first',
    // Broadcast / media noise — appear in almost every headline but signal nothing
    'live', 'breaking', 'update', 'updates', 'watch', 'video', 'exclusive',
    'says', 'said', 'say', 'report', 'reports', 'reported',
    'warn', 'warns', 'warned', 'calls', 'hits', 'reveals', 'revealed',
    'reveal', 'shows', 'read', 'here', 'know', 'inside', 'ahead', 'back',
    'claim', 'claims', 'claimed', 'joins', 'join', 'seen',
    'slams', 'slam', 'blasts', 'blast',
    // Clickbait / sensationalist adjectives
    'major', 'massive', 'huge', 'historic', 'dramatic', 'shocking', 'stunning',
    'urgent', 'critical', 'key', 'special', 'viral', 'bold', 'rare', 'giant',
    'biggest', 'largest', 'worst', 'greatest', 'powerful', 'important',
    // Headline verbs that carry no topical meaning
    'makes', 'takes', 'gets', 'gives', 'faces', 'needs', 'wants', 'plans',
    'seeks', 'asks', 'tells', 'finds', 'turns', 'runs', 'wins', 'loses',
    'beats', 'leads', 'ends', 'begins', 'starts', 'comes', 'goes', 'sets',
    'puts', 'brings', 'keeps', 'looks', 'responds', 'react',
    'reacts', 'reacted', 'fires', 'fired', 'push', 'pushes', 'pushed',
    // Time / recency noise
    'today', 'tonight', 'soon', 'already', 'still', 'again', 'ever', 'once',
    'daily', 'weekly', 'amid', 'hours', 'days', 'weeks', 'months', 'years',
    // Article format words
    'recap', 'roundup', 'explainer', 'analysis', 'opinion', 'review',
    'interview', 'podcast', 'episode', 'series', 'guide', 'preview',
    'edition', 'column', 'feature', 'story', 'piece', 'coverage',
    // Social / engagement noise
    'share', 'shares', 'follow', 'subscribe', 'trending', 'popular',
    // Connectors common in headlines
    'despite', 'following', 'including', 'between', 'against', 'during',
    'regarding', 'across', 'without', 'within', 'under', 'through',
  };

  /// Main entry point. Accepts per-source raw lists and returns a unified,
  /// ranked, clustered list ready for the UI.
  List<TrendItem> process({
    required List<TrendItem> youtubeItems,
    required List<TrendItem> redditItems,
    required List<TrendItem> newsItems,
    required List<TrendItem> githubItems,
    List<TrendItem> hnItems = const [],
    List<TrendItem> phItems = const [],
    List<TrendItem> devToItems = const [],
  }) {
    final all = [
      ...youtubeItems,
      ...redditItems,
      ...newsItems,
      ...githubItems,
      ...hnItems,
      ...phItems,
      ...devToItems,
    ];
    if (all.isEmpty) return all;

    var items = _normalizeScores(all);
    items = _applyDecay(items);
    items = _extractTags(items);
    items = _assignSentiment(items);
    items = _assignClusters(items);
    items = _assignMomentum(items);
    items = _deduplicateClusters(items);

    items.sort((a, b) => b.normalizedScore.compareTo(a.normalizedScore));
    return items;
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Normalize raw scores to 0–100, then apply source weight + dampening
  // ---------------------------------------------------------------------------

  List<TrendItem> _normalizeScores(List<TrendItem> items) {
    final bySource = <TrendSource, List<TrendItem>>{};
    for (final item in items) {
      bySource.putIfAbsent(item.source, () => []).add(item);
    }

    final result = <TrendItem>[];
    for (final entry in bySource.entries) {
      final source = entry.key;
      final group = entry.value;
      
      // Handle cases where some items might not have a raw score
      final scores = group.map((i) => i.score?.toDouble() ?? 0.0).toList();
      final maxScore = scores.isEmpty ? 0.0 : scores.reduce(max);
      final minScore = scores.isEmpty ? 0.0 : scores.reduce(min);
      final range = maxScore - minScore;

      final weight = _sourceWeights[source] ?? 1.0;
      // Dampen outlier noise: a lone 1–2 item source shouldn't dominate the feed
      final dampen = group.length <= 2 ? 0.8 : 1.0;
      final multiplier = weight * dampen;

      for (final item in group) {
        final raw = item.score?.toDouble() ?? 0.0;
        // When all items in a source have the same score (range == 0), give 50
        final normalized = range > 0 ? ((raw - minScore) / range) * 100.0 : 50.0;
        final weighted = (normalized * multiplier).clamp(0.0, 100.0);
        result.add(item.copyWith(normalizedScore: weighted));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Recency decay (exponential, half-life = 24 hours)
  // ---------------------------------------------------------------------------

  List<TrendItem> _applyDecay(List<TrendItem> items) {
    const halfLifeHours = 24.0;
    const lambda = 0.693147 / halfLifeHours; // ln(2) / half-life

    final now = DateTime.now();
    return items.map((item) {
      final ageHours = now.difference(item.publishedAt).inMinutes / 60.0;
      final decay = exp(-lambda * ageHours.clamp(0.0, double.infinity));
      final decayed = (item.normalizedScore * decay).clamp(0.0, 100.0);
      return item.copyWith(normalizedScore: decayed);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Extract significant keywords as tags
  // ---------------------------------------------------------------------------

  List<TrendItem> _extractTags(List<TrendItem> items) {
    return items.map((item) {
      final tags = _tokenize(item.title)
          .where((w) => w.length > 3 && !_stopWords.contains(w))
          .toSet() // deduplicate
          .take(6)
          .toList();
      return item.copyWith(tags: tags);
    }).toList();
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // ---------------------------------------------------------------------------
  // Step 3.5 — Sentiment detection
  // ---------------------------------------------------------------------------

  List<TrendItem> _assignSentiment(List<TrendItem> items) {
    return items
        .map((item) => item.copyWith(sentiment: SentimentEngine.detect(item)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Step 4 — Cluster items by shared keywords (≥3) or same domain/repo
  // ---------------------------------------------------------------------------

  List<TrendItem> _assignClusters(List<TrendItem> items) {
    // parent[i] tracks the canonical cluster index for item i (union-find)
    final parent = List<int>.generate(items.length, (i) => i);

    int find(int i) {
      if (parent[i] != i) parent[i] = find(parent[i]);
      return parent[i];
    }

    void union(int a, int b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    // Pre-compute domains to avoid repeated URI parsing
    final domains = items.map((i) => _extractDomain(i.url)).toList();

    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        if (_shouldCluster(items[i], items[j], domains[i], domains[j])) {
          union(i, j);
        }
      }
    }

    // Count items per root so we skip singletons (no sibling = no cluster)
    final rootCounts = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final r = find(i);
      rootCounts[r] = (rootCounts[r] ?? 0) + 1;
    }

    // Map each multi-item root to a stable cluster ID string
    final rootToId = <int, String>{};
    int counter = 0;

    return [
      for (int i = 0; i < items.length; i++)
        () {
          final root = find(i);
          if ((rootCounts[root] ?? 0) <= 1) return items[i]; // singleton
          final id = rootToId.putIfAbsent(root, () => 'cluster_${counter++}');
          return items[i].copyWith(clusterId: id);
        }(),
    ];
  }

  bool _shouldCluster(
    TrendItem a,
    TrendItem b,
    String? domainA,
    String? domainB,
  ) {
    // Rule 1: same specific domain/repo/subreddit
    if (domainA != null && domainA == domainB) return true;

    // Rule 2: at least 3 shared significant keywords
    final shared = a.tags.toSet().intersection(b.tags.toSet());
    return shared.length >= 3;
  }

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;

      if (host.contains('github.com')) {
        final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (parts.length >= 2) return 'github:${parts[0]}/${parts[1]}';
        return null;
      }

      if (host.contains('reddit.com')) {
        final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        // Only cluster within the same subreddit, not Reddit broadly
        if (parts.length >= 2 && parts[0] == 'r') return 'reddit:${parts[1]}';
        return null;
      }

      // Do not cluster news/YouTube by outlet — one outlet covers many unrelated
      // stories, so domain-based grouping creates false cross-topic clusters.
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Step 5 — Assign momentum label based on age + score
  // ---------------------------------------------------------------------------

  List<TrendItem> _assignMomentum(List<TrendItem> items) {
    final now = DateTime.now();
    return items.map((item) {
      final ageHours = now.difference(item.publishedAt).inMinutes / 60.0;
      final s = item.normalizedScore;

      final String momentum;
      if (ageHours <= 6 && s >= 35) {
        momentum = 'rising';
      } else if (ageHours > 48 || s < 15) {
        momentum = 'cooling';
      } else {
        momentum = 'stable';
      }

      return item.copyWith(momentum: momentum);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Step 6 — Deduplicate near-identical items within the same cluster
  // ---------------------------------------------------------------------------

  /// Removes lower-scoring duplicates from each cluster when two items share
  /// >90% Jaccard word-overlap (i.e. the same story from two sources).
  List<TrendItem> _deduplicateClusters(List<TrendItem> items) {
    // Group indices by clusterId — only clustered items can be near-duplicates
    final clusters = <String, List<int>>{};
    for (int i = 0; i < items.length; i++) {
      final cid = items[i].clusterId;
      if (cid != null) clusters.putIfAbsent(cid, () => []).add(i);
    }

    final toRemove = <int>{};

    for (final indices in clusters.values) {
      if (indices.length < 2) continue;
      for (int a = 0; a < indices.length; a++) {
        for (int b = a + 1; b < indices.length; b++) {
          final ia = indices[a], ib = indices[b];
          if (toRemove.contains(ia) || toRemove.contains(ib)) continue;
          if (_titleSimilarity(items[ia].title, items[ib].title) > 0.9) {
            // Drop the lower-scoring duplicate
            if (items[ia].normalizedScore >= items[ib].normalizedScore) {
              toRemove.add(ib);
            } else {
              toRemove.add(ia);
            }
          }
        }
      }
    }

    if (toRemove.isEmpty) return items;
    return [
      for (int i = 0; i < items.length; i++)
        if (!toRemove.contains(i)) items[i],
    ];
  }

  /// Jaccard word-overlap similarity between two titles (0.0–1.0).
  double _titleSimilarity(String a, String b) {
    final wordsA = _tokenize(a).toSet();
    final wordsB = _tokenize(b).toSet();
    if (wordsA.isEmpty && wordsB.isEmpty) return 1.0;
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return intersection / union;
  }
}
