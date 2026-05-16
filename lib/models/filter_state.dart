import 'package:flutter/foundation.dart';

enum DateFilter { any, last24h, lastWeek, lastMonth }

enum SortOrder { score, date }

enum FeedRegion { global, india }

enum FeedCategory { all, tech, finance, entertainment, gaming, startups }

/// Names of the available RSS news sources (matches keys in NewsService).
const kAllNewsSources = {
  'BBC News',
  'Times of India',
  'NDTV',
  'The Hindu',
  'Al Jazeera',
  'Reuters',
  'India Today',
};

/// Popular GitHub languages offered in the language filter.
const kGithubLanguages = [
  'JavaScript',
  'TypeScript',
  'Python',
  'Rust',
  'Go',
  'Java',
  'Kotlin',
  'Swift',
  'C++',
  'C',
  'Dart',
  'Ruby',
  'PHP',
  'Shell',
  'Scala',
];

@immutable
class FilterState {
  final Set<String> enabledPlatforms;

  // ── Per-source score thresholds (applied client-side) ──────────────────────
  final int minYoutubeViews;
  final int minRedditUpvotes;
  final int minGithubStars;

  // ── GitHub-specific ────────────────────────────────────────────────────────
  /// Empty set = all languages (no restriction).
  final Set<String> githubLanguages;

  // ── Reddit-specific ────────────────────────────────────────────────────────
  /// Specific subreddits to fetch. Empty list = use r/popular (default).
  /// Set by topic presets; not exposed in the manual filter UI.
  final List<String> redditSubreddits;

  // ── News-specific ──────────────────────────────────────────────────────────
  /// Empty set = all sources enabled (backward-compatible default).
  final Set<String> enabledNewsSources;

  // ── YouTube-specific ───────────────────────────────────────────────────────
  /// YouTube trending category ID (e.g. '20' = Gaming, '24' = Entertainment).
  /// Null = no category restriction (mostPopular across all categories).
  final String? youtubeCategoryId;

  // ── Phase 2: Region & Category ─────────────────────────────────────────────
  final FeedRegion region;
  final FeedCategory category;

  // ── Shared ─────────────────────────────────────────────────────────────────
  final DateFilter dateFilter;
  final SortOrder sortOrder;
  final bool safeSearch;

  const FilterState({
    this.enabledPlatforms = const {
      'youtube',
      'reddit',
      'news',
      'github',
      'hackerNews',
      'productHunt',
      'devTo'
    },
    this.minYoutubeViews = 0,
    this.minRedditUpvotes = 0,
    this.minGithubStars = 0,
    this.githubLanguages = const {},
    this.redditSubreddits = const [],
    this.enabledNewsSources = const {},
    this.youtubeCategoryId,
    this.region = FeedRegion.global,
    this.category = FeedCategory.all,
    this.dateFilter = DateFilter.any,
    this.sortOrder = SortOrder.score,
    this.safeSearch = false,
  });

  bool get youtubeEnabled => enabledPlatforms.contains('youtube');
  bool get redditEnabled => enabledPlatforms.contains('reddit');
  bool get newsEnabled => enabledPlatforms.contains('news');
  bool get githubEnabled => enabledPlatforms.contains('github');
  bool get hackerNewsEnabled => enabledPlatforms.contains('hackerNews');
  bool get productHuntEnabled => enabledPlatforms.contains('productHunt');
  bool get devToEnabled => enabledPlatforms.contains('devTo');

  /// Resolved set of enabled news sources — empty stored set means all.
  Set<String> get resolvedNewsSources =>
      enabledNewsSources.isEmpty ? kAllNewsSources : enabledNewsSources;

  /// True when any filter deviates from defaults (used for badge display).
  bool get hasActiveFilters =>
      enabledPlatforms.length < 7 ||
      minYoutubeViews > 0 ||
      minRedditUpvotes > 0 ||
      minGithubStars > 0 ||
      githubLanguages.isNotEmpty ||
      enabledNewsSources.isNotEmpty ||
      dateFilter != DateFilter.any ||
      sortOrder != SortOrder.score ||
      safeSearch;

  FilterState copyWith({
    Set<String>? enabledPlatforms,
    int? minYoutubeViews,
    int? minRedditUpvotes,
    int? minGithubStars,
    Set<String>? githubLanguages,
    List<String>? redditSubreddits,
    Set<String>? enabledNewsSources,
    String? youtubeCategoryId,
    bool clearYoutubeCategoryId = false,
    FeedRegion? region,
    FeedCategory? category,
    DateFilter? dateFilter,
    SortOrder? sortOrder,
    bool? safeSearch,
  }) =>
      FilterState(
        enabledPlatforms: enabledPlatforms ?? this.enabledPlatforms,
        minYoutubeViews: minYoutubeViews ?? this.minYoutubeViews,
        minRedditUpvotes: minRedditUpvotes ?? this.minRedditUpvotes,
        minGithubStars: minGithubStars ?? this.minGithubStars,
        githubLanguages: githubLanguages ?? this.githubLanguages,
        redditSubreddits: redditSubreddits ?? this.redditSubreddits,
        enabledNewsSources: enabledNewsSources ?? this.enabledNewsSources,
        youtubeCategoryId: clearYoutubeCategoryId
            ? null
            : (youtubeCategoryId ?? this.youtubeCategoryId),
        region: region ?? this.region,
        category: category ?? this.category,
        dateFilter: dateFilter ?? this.dateFilter,
        sortOrder: sortOrder ?? this.sortOrder,
        safeSearch: safeSearch ?? this.safeSearch,
      );

  Map<String, dynamic> toMap() => {
        'enabledPlatforms': enabledPlatforms.toList(),
        'minYoutubeViews': minYoutubeViews,
        'minRedditUpvotes': minRedditUpvotes,
        'minGithubStars': minGithubStars,
        'githubLanguages': githubLanguages.toList(),
        'enabledNewsSources': enabledNewsSources.toList(),
        if (youtubeCategoryId != null) 'youtubeCategoryId': youtubeCategoryId,
        'region': region.name,
        'category': category.name,
        'dateFilter': dateFilter.name,
        'sortOrder': sortOrder.name,
        'safeSearch': safeSearch,
      };

  factory FilterState.fromMap(Map<String, dynamic> map) => FilterState(
        enabledPlatforms: {
          ...Set<String>.from(map['enabledPlatforms'] as List? ??
              ['youtube', 'reddit', 'news', 'github', 'hackerNews', 'productHunt', 'devTo']),
          'hackerNews',
          'productHunt',
          'devTo',
        },
        minYoutubeViews: (map['minYoutubeViews'] as num?)?.toInt() ?? 0,
        minRedditUpvotes: (map['minRedditUpvotes'] as num?)?.toInt() ?? 0,
        minGithubStars: (map['minGithubStars'] as num?)?.toInt() ?? 0,
        githubLanguages: Set<String>.from(map['githubLanguages'] as List? ?? []),
        enabledNewsSources: Set<String>.from(map['enabledNewsSources'] as List? ?? []),
        youtubeCategoryId: map['youtubeCategoryId'] as String?,
        region: FeedRegion.values.firstWhere(
          (e) => e.name == map['region'],
          orElse: () => FeedRegion.global,
        ),
        category: FeedCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => FeedCategory.all,
        ),
        dateFilter: DateFilter.values.firstWhere(
          (e) => e.name == map['dateFilter'],
          orElse: () => DateFilter.any,
        ),
        sortOrder: SortOrder.values.firstWhere(
          (e) => e.name == map['sortOrder'],
          orElse: () => SortOrder.score,
        ),
        safeSearch: map['safeSearch'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          runtimeType == other.runtimeType &&
          setEquals(enabledPlatforms, other.enabledPlatforms) &&
          minYoutubeViews == other.minYoutubeViews &&
          minRedditUpvotes == other.minRedditUpvotes &&
          minGithubStars == other.minGithubStars &&
          setEquals(githubLanguages, other.githubLanguages) &&
          listEquals(redditSubreddits, other.redditSubreddits) &&
          setEquals(enabledNewsSources, other.enabledNewsSources) &&
          youtubeCategoryId == other.youtubeCategoryId &&
          region == other.region &&
          category == other.category &&
          dateFilter == other.dateFilter &&
          sortOrder == other.sortOrder &&
          safeSearch == other.safeSearch;

  @override
  int get hashCode => Object.hash(
        enabledPlatforms,
        minYoutubeViews,
        minRedditUpvotes,
        minGithubStars,
        githubLanguages,
        Object.hashAll(redditSubreddits),
        enabledNewsSources,
        youtubeCategoryId,
        region,
        category,
        dateFilter,
        sortOrder,
        safeSearch,
      );
}
