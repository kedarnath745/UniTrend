import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/filter_state.dart';
import '../models/trend_item.dart';

// Category → GitHub topic search qualifier
const _categoryTopics = <FeedCategory, String>{
  FeedCategory.tech:          'topic:ai',
  FeedCategory.gaming:        'topic:game',
  FeedCategory.finance:       'topic:finance',
  FeedCategory.startups:      'topic:startup',
  FeedCategory.entertainment: 'topic:media',
};

class GitHubService {
  static const _baseUrl = 'https://api.github.com';

  // Optional token for higher rate limits (60 → 5000 req/hour)
  String? get _token => dotenv.env['GITHUB_TOKEN'];

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<List<TrendItem>> fetchTrending({FilterState? filters}) async {
    final since = _sinceDate(filters?.dateFilter ?? DateFilter.lastWeek);
    final langClause = _langClause(filters?.githubLanguages);
    final topicClause = _topicClause(filters?.category);
    final uri =
        Uri.parse('$_baseUrl/search/repositories').replace(queryParameters: {
      'q': 'pushed:>$since$langClause$topicClause',
      'sort': 'stars',
      'order': 'desc',
      'per_page': '20',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;

    return items.map((repo) => _repoToTrendItem(repo as Map<String, dynamic>)).toList();
  }

  Future<List<TrendItem>> search(String query, {FilterState? filters}) async {
    final params = <String, String>{
      'q': query,
      'sort': 'stars',
      'order': 'desc',
      'per_page': '20',
    };

    if (filters != null && filters.dateFilter != DateFilter.any) {
      final since = _sinceDate(filters.dateFilter);
      params['q'] = '$query pushed:>$since';
    }
    final langClause = _langClause(filters?.githubLanguages);
    if (langClause.isNotEmpty) {
      params['q'] = '${params['q'] ?? query}$langClause';
    }

    final uri = Uri.parse('$_baseUrl/search/repositories')
        .replace(queryParameters: params);

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('GitHub search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;

    return items.map((repo) => _repoToTrendItem(repo as Map<String, dynamic>)).toList();
  }

  TrendItem _repoToTrendItem(Map<String, dynamic> repo) {
    final owner = repo['owner'] as Map<String, dynamic>;
    final language = repo['language'] as String?;
    final description = repo['description'] as String?;
    final stars = repo['stargazers_count'] as int? ?? 0;

    // Reason: high-star repos signal velocity spike; new repos are "rising"
    final createdAt = DateTime.tryParse(repo['created_at'] as String? ?? '');
    final isNew = createdAt != null &&
        DateTime.now().difference(createdAt).inDays < 30;
    final reason = stars >= 1000
        ? 'Star Velocity Spike'
        : isNew
            ? 'New & Rising on GitHub'
            : 'Trending on GitHub';

    return TrendItem(
      id: 'gh_${repo['id']}',
      title: repo['full_name'] as String,
      description: description != null && description.isNotEmpty
          ? description
          : null,
      thumbnailUrl: owner['avatar_url'] as String?,
      url: repo['html_url'] as String,
      source: TrendSource.github,
      author: owner['login'] as String?,
      // pushed_at reflects the last activity, which is what matters for
      // trending detection. created_at (repo birth) is useless for decay scoring.
      publishedAt: DateTime.tryParse(
            (repo['pushed_at'] ?? repo['updated_at'] ?? repo['created_at'])
                    as String? ??
                '',
          ) ??
          DateTime.now(),
      score: stars,
      sourceName: language ?? 'GitHub',
      trendingReason: reason,
    );
  }

  /// Builds a GitHub language query clause, e.g. " language:Python language:Rust".
  String _langClause(Set<String>? langs) {
    if (langs == null || langs.isEmpty) return '';
    return langs.map((l) => ' language:$l').join();
  }

  /// Builds a GitHub topic query clause for a given FeedCategory.
  String _topicClause(FeedCategory? category) {
    if (category == null || category == FeedCategory.all) return '';
    final topic = _categoryTopics[category];
    return topic != null ? ' $topic' : '';
  }

  String _sinceDate(DateFilter filter) {
    final now = DateTime.now().toUtc();
    final date = switch (filter) {
      DateFilter.last24h => now.subtract(const Duration(hours: 24)),
      DateFilter.lastWeek => now.subtract(const Duration(days: 7)),
      DateFilter.lastMonth => now.subtract(const Duration(days: 30)),
      DateFilter.any => now.subtract(const Duration(days: 90)), // broader window
    };
    return date.toIso8601String().split('T').first; // yyyy-MM-dd
  }
}
