import '../models/feedback_entry.dart';
import '../models/trend_item.dart';

class PersonalizationProfile {
  final Map<TrendSource, double> sourceAffinity;
  final Map<String, double> keywordAffinity;
  final Map<String, double> clusterAffinity;
  final Map<String, double> sourceNameAffinity;
  final Map<String, double> authorAffinity;
  final Set<String> likedItemIds;
  final Set<String> dislikedItemIds;

  const PersonalizationProfile({
    this.sourceAffinity = const {},
    this.keywordAffinity = const {},
    this.clusterAffinity = const {},
    this.sourceNameAffinity = const {},
    this.authorAffinity = const {},
    this.likedItemIds = const {},
    this.dislikedItemIds = const {},
  });

  bool get hasSignals =>
      sourceAffinity.isNotEmpty ||
      keywordAffinity.isNotEmpty ||
      clusterAffinity.isNotEmpty ||
      sourceNameAffinity.isNotEmpty ||
      authorAffinity.isNotEmpty ||
      likedItemIds.isNotEmpty ||
      dislikedItemIds.isNotEmpty;
}

class PersonalizationEngine {
  static const _stopWords = {
    'the',
    'and',
    'for',
    'with',
    'that',
    'this',
    'from',
    'into',
    'your',
    'about',
    'what',
    'when',
    'where',
    'will',
    'would',
    'there',
    'their',
    'have',
    'has',
    'been',
    'were',
    'they',
    'them',
    'just',
    'than',
    'then',
    'more',
    'also',
    'over',
    'under',
    'across',
    'latest',
    'breaking',
    'video',
    'news',
    'post',
    'posts',
    'update',
    'updates',
    'guide',
    'review',
    'today',
  };

  PersonalizationProfile buildProfile({
    required List<FeedbackEntry> feedbackEntries,
    required List<TrendItem> bookmarks,
    required List<String> searchQueries,
  }) {
    final sourceAffinity = <TrendSource, double>{};
    final keywordAffinity = <String, double>{};
    final clusterAffinity = <String, double>{};
    final sourceNameAffinity = <String, double>{};
    final authorAffinity = <String, double>{};
    final likedItemIds = <String>{};
    final dislikedItemIds = <String>{};

    void addKeywordSignal(Iterable<String> tokens, double delta) {
      for (final token in tokens) {
        keywordAffinity[token] = (keywordAffinity[token] ?? 0) + delta;
      }
    }

    for (final entry in feedbackEntries) {
      final sourceDelta = entry.isPositive ? 1.35 : -1.6;
      final clusterDelta = entry.isPositive ? 2.0 : -2.4;
      final keywordDelta = entry.isPositive ? 1.2 : -1.35;
      final nameDelta = entry.isPositive ? 0.8 : -0.95;
      final authorDelta = entry.isPositive ? 0.55 : -0.7;

      sourceAffinity[entry.source] =
          (sourceAffinity[entry.source] ?? 0) + sourceDelta;
      addKeywordSignal(entry.tags, keywordDelta);
      addKeywordSignal(_tokenize(entry.title), keywordDelta * 0.8);

      if (entry.clusterId != null && entry.clusterId!.isNotEmpty) {
        clusterAffinity[entry.clusterId!] =
            (clusterAffinity[entry.clusterId!] ?? 0) + clusterDelta;
      }

      for (final token in _tokenize(entry.sourceName ?? '')) {
        sourceNameAffinity[token] = (sourceNameAffinity[token] ?? 0) + nameDelta;
      }
      for (final token in _tokenize(entry.author ?? '')) {
        authorAffinity[token] = (authorAffinity[token] ?? 0) + authorDelta;
      }

      if (entry.isPositive) {
        likedItemIds.add(entry.itemId);
      } else {
        dislikedItemIds.add(entry.itemId);
      }
    }

    for (final bookmark in bookmarks) {
      sourceAffinity[bookmark.source] =
          (sourceAffinity[bookmark.source] ?? 0) + 0.9;
      addKeywordSignal(bookmark.tags, 0.8);
      addKeywordSignal(_tokenize(bookmark.title), 0.55);

      if (bookmark.clusterId != null && bookmark.clusterId!.isNotEmpty) {
        clusterAffinity[bookmark.clusterId!] =
            (clusterAffinity[bookmark.clusterId!] ?? 0) + 1.3;
      }

      for (final token in _tokenize(bookmark.sourceName ?? '')) {
        sourceNameAffinity[token] = (sourceNameAffinity[token] ?? 0) + 0.55;
      }
      for (final token in _tokenize(bookmark.author ?? '')) {
        authorAffinity[token] = (authorAffinity[token] ?? 0) + 0.35;
      }
    }

    for (int i = 0; i < searchQueries.length; i++) {
      final recencyWeight = (1.0 - (i * 0.12)).clamp(0.4, 1.0).toDouble();
      for (final token in _tokenize(searchQueries[i])) {
        keywordAffinity[token] =
            (keywordAffinity[token] ?? 0) + 0.6 * recencyWeight;
        sourceNameAffinity[token] =
            (sourceNameAffinity[token] ?? 0) + 0.35 * recencyWeight;
      }
    }

    return PersonalizationProfile(
      sourceAffinity: sourceAffinity,
      keywordAffinity: keywordAffinity,
      clusterAffinity: clusterAffinity,
      sourceNameAffinity: sourceNameAffinity,
      authorAffinity: authorAffinity,
      likedItemIds: likedItemIds,
      dislikedItemIds: dislikedItemIds,
    );
  }

  List<TrendItem> rerank(List<TrendItem> items, PersonalizationProfile profile) {
    if (!profile.hasSignals) return items;

    final adjusted = items.map((item) {
      if (profile.dislikedItemIds.contains(item.id)) {
        return item.copyWith(normalizedScore: item.normalizedScore * 0.08);
      }

      var multiplier = 1.0;
      multiplier += (profile.sourceAffinity[item.source] ?? 0) * 0.09;

      final keywordMatches = {
        ...item.tags,
        ..._tokenize(item.title),
        ..._tokenize(item.description ?? ''),
      };
      multiplier +=
          _averageAffinity(keywordMatches, profile.keywordAffinity) * 0.12;

      if (item.clusterId != null) {
        multiplier += (profile.clusterAffinity[item.clusterId!] ?? 0) * 0.18;
      }

      multiplier += _averageAffinity(
            _tokenize(item.sourceName ?? ''),
            profile.sourceNameAffinity,
          ) *
          0.08;
      multiplier += _averageAffinity(
            _tokenize(item.author ?? ''),
            profile.authorAffinity,
          ) *
          0.05;

      if (profile.likedItemIds.contains(item.id)) {
        multiplier += 0.35;
      }

      final adjustedScore = (item.normalizedScore *
              multiplier.clamp(0.25, 1.9).toDouble())
          .clamp(0.0, 100.0)
          .toDouble();
      return item.copyWith(normalizedScore: adjustedScore);
    }).toList()
      ..sort((a, b) => b.normalizedScore.compareTo(a.normalizedScore));

    return adjusted;
  }

  double _averageAffinity(Iterable<String> tokens, Map<String, double> affinity) {
    final matches = <double>[];
    for (final token in tokens) {
      final value = affinity[token];
      if (value != null) matches.add(value);
    }
    if (matches.isEmpty) return 0.0;
    return matches.reduce((a, b) => a + b) / matches.length;
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 2 && !_stopWords.contains(token))
      .toList();
}
