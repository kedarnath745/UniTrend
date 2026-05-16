enum TrendSource { youtube, reddit, news, github, hackerNews, productHunt, devTo }

enum TrendSentiment { neutral, positive, critical, controversial }

class TrendItem {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String url;
  final TrendSource source;
  final String? author;
  final DateTime publishedAt;
  final int? score;
  final String? sourceName; // subreddit, channel name, or news outlet

  // Trend Intelligence Engine fields
  final double normalizedScore; // 0–100, recency-decayed cross-source score
  final String momentum; // 'rising' | 'stable' | 'cooling'
  final String? clusterId; // non-null when item belongs to a topic cluster
  final List<String> tags; // significant keywords extracted from title

  // Phase 2: Why is this trending?
  final String? trendingReason; // e.g. 'Breaking: BBC News', 'Hot in r/india'

  // Sentiment detected from title + description
  final TrendSentiment sentiment;

  const TrendItem({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.url,
    required this.source,
    this.author,
    required this.publishedAt,
    this.score,
    this.sourceName,
    this.normalizedScore = 0.0,
    this.momentum = 'stable',
    this.clusterId,
    this.tags = const [],
    this.trendingReason,
    this.sentiment = TrendSentiment.neutral,
  });

  String get sourceLabel {
    switch (source) {
      case TrendSource.youtube:
        return 'YouTube';
      case TrendSource.reddit:
        return 'Reddit';
      case TrendSource.news:
        return 'News';
      case TrendSource.github:
        return 'GitHub';
      case TrendSource.hackerNews:
        return 'Hacker News';
      case TrendSource.productHunt:
        return 'Product Hunt';
      case TrendSource.devTo:
        return 'Dev.to';
    }
  }

  TrendItem copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? url,
    TrendSource? source,
    String? author,
    DateTime? publishedAt,
    int? score,
    String? sourceName,
    double? normalizedScore,
    String? momentum,
    Object? clusterId = _sentinel,
    List<String>? tags,
    Object? trendingReason = _sentinel,
    TrendSentiment? sentiment,
  }) =>
      TrendItem(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        url: url ?? this.url,
        source: source ?? this.source,
        author: author ?? this.author,
        publishedAt: publishedAt ?? this.publishedAt,
        score: score ?? this.score,
        sourceName: sourceName ?? this.sourceName,
        normalizedScore: normalizedScore ?? this.normalizedScore,
        momentum: momentum ?? this.momentum,
        clusterId: identical(clusterId, _sentinel)
            ? this.clusterId
            : clusterId as String?,
        tags: tags ?? this.tags,
        trendingReason: identical(trendingReason, _sentinel)
            ? this.trendingReason
            : trendingReason as String?,
        sentiment: sentiment ?? this.sentiment,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'url': url,
        'source': source.name,
        'author': author,
        'publishedAt': publishedAt.toIso8601String(),
        'score': score,
        'sourceName': sourceName,
        'normalizedScore': normalizedScore,
        'momentum': momentum,
        'clusterId': clusterId,
        'tags': tags,
        'trendingReason': trendingReason,
        'sentiment': sentiment.name,
      };

  factory TrendItem.fromMap(Map<String, dynamic> map) => TrendItem(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        url: map['url'] as String,
        source: TrendSource.values.firstWhere(
          (s) => s.name == map['source'],
          orElse: () => TrendSource.news,
        ),
        author: map['author'] as String?,
        publishedAt: DateTime.parse(map['publishedAt'] as String),
        score: map['score'] as int?,
        sourceName: map['sourceName'] as String?,
        normalizedScore: (map['normalizedScore'] as num?)?.toDouble() ?? 0.0,
        momentum: map['momentum'] as String? ?? 'stable',
        clusterId: map['clusterId'] as String?,
        tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
        trendingReason: map['trendingReason'] as String?,
        sentiment: TrendSentiment.values.firstWhere(
          (s) => s.name == map['sentiment'],
          orElse: () => TrendSentiment.neutral,
        ),
      );
}

// Sentinel object used by copyWith to distinguish "pass null" from "omit field"
const Object _sentinel = Object();
