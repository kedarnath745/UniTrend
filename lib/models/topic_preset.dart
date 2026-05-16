import 'package:flutter/material.dart';
import 'filter_state.dart';

class TopicPreset {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// Which platforms are enabled for this preset.
  final Set<String> enabledPlatforms;

  /// Specific subreddits to fetch instead of r/popular.
  /// Empty list = use r/popular (never set empty here; only the null preset does).
  final List<String> redditSubreddits;

  /// GitHub language filter. Empty = all languages.
  final Set<String> githubLanguages;

  /// News sources to include. Empty = all sources.
  final Set<String> enabledNewsSources;

  /// YouTube trending category ID. Null = no category filter.
  /// 20 = Gaming, 24 = Entertainment.
  final String? youtubeCategoryId;

  const TopicPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabledPlatforms,
    required this.redditSubreddits,
    this.githubLanguages = const {},
    this.enabledNewsSources = const {},
    this.youtubeCategoryId,
  });

  /// Returns a new FilterState that overlays this preset's topic config on top
  /// of [base]. The user's saved preferences (minViews, dateFilter, safeSearch,
  /// sortOrder, etc.) are preserved — only source routing changes.
  FilterState applyTo(FilterState base) => base.copyWith(
        enabledPlatforms: enabledPlatforms,
        redditSubreddits: redditSubreddits,
        githubLanguages: githubLanguages,
        enabledNewsSources: enabledNewsSources,
        youtubeCategoryId: youtubeCategoryId,
        clearYoutubeCategoryId: youtubeCategoryId == null,
      );
}

/// All available topic presets.
///
/// YouTube note: The YouTube trending API has no category filter.
/// Presets only enable YouTube where trending videos are genuinely
/// aligned with the topic (Tech, Gaming, Entertainment).
/// Sports / Finance / Science disable YouTube rather than fake-filter it.
const kTopicPresets = [
  TopicPreset(
    id: 'tech',
    label: 'Tech',
    icon: Icons.computer_rounded,
    color: Color(0xFF6366F1),
    enabledPlatforms: {
      'youtube',
      'reddit',
      'news',
      'github',
      'hackerNews',
      'productHunt',
      'devTo',
    },
    redditSubreddits: ['technology', 'programming', 'MachineLearning', 'webdev'],
    githubLanguages: {'JavaScript', 'TypeScript', 'Python', 'Rust', 'Go', 'Dart'},
  ),
  TopicPreset(
    id: 'gaming',
    label: 'Gaming',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF8B5CF6),
    enabledPlatforms: {'youtube', 'reddit', 'github'},
    redditSubreddits: ['gaming', 'gamedev', 'pcgaming', 'Games'],
    githubLanguages: {'C++', 'C', 'Python', 'Lua', 'GDScript'},
    youtubeCategoryId: '20', // YouTube Gaming category
  ),
  TopicPreset(
    id: 'sports',
    label: 'Sports',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF10B981),
    enabledPlatforms: {'youtube', 'reddit', 'news'},
    redditSubreddits: ['sports', 'soccer', 'cricket', 'nba', 'formula1'],
  ),
  TopicPreset(
    id: 'finance',
    label: 'Finance',
    icon: Icons.show_chart_rounded,
    color: Color(0xFFF59E0B),
    enabledPlatforms: {'youtube', 'reddit', 'news', 'github'},
    redditSubreddits: ['investing', 'personalfinance', 'economics', 'stocks'],
    githubLanguages: {'Python', 'R', 'Scala', 'Julia'},
    enabledNewsSources: {'Reuters', 'BBC News'},
  ),
  TopicPreset(
    id: 'science',
    label: 'Science',
    icon: Icons.science_rounded,
    color: Color(0xFF06B6D4),
    enabledPlatforms: {'youtube', 'reddit', 'news', 'github'},
    redditSubreddits: ['science', 'space', 'physics', 'askscience'],
    githubLanguages: {'Python', 'R', 'Julia', 'C++', 'Fortran'},
    enabledNewsSources: {'BBC News', 'Reuters', 'Al Jazeera'},
  ),
  TopicPreset(
    id: 'entertainment',
    label: 'Entertainment',
    icon: Icons.movie_rounded,
    color: Color(0xFFEC4899),
    enabledPlatforms: {'youtube', 'reddit', 'news'},
    redditSubreddits: ['movies', 'television', 'Music', 'entertainment'],
    youtubeCategoryId: '24', // YouTube Entertainment category
  ),
];
