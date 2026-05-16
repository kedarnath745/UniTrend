import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/filter_state.dart';
import '../models/trend_item.dart';
import '../models/reddit_post.dart';

// Category → subreddits mapping
const _categorySubreddits = <FeedCategory, List<String>>{
  FeedCategory.tech:          ['technology', 'programming', 'compsci'],
  FeedCategory.finance:       ['IndiaInvestments', 'wallstreetbets', 'personalfinance'],
  FeedCategory.entertainment: ['movies', 'television', 'bollywood'],
  FeedCategory.gaming:        ['gaming', 'IndianGaming', 'pcgaming'],
  FeedCategory.startups:      ['startups', 'indianstartups', 'entrepreneur'],
};

class RedditService {
  static const _baseUrl = 'https://www.reddit.com';
  static const _headers = {
    'User-Agent': 'android:com.unitrend.app:v1.0.0 (by /u/unitrend_app)',
  };

  String _redditTime(DateFilter dateFilter) {
    switch (dateFilter) {
      case DateFilter.last24h:
        return 'day';
      case DateFilter.lastWeek:
        return 'week';
      case DateFilter.lastMonth:
        return 'month';
      case DateFilter.any:
        return 'all';
    }
  }

  /// Resolves which subreddits to fetch, respecting category and manual overrides.
  List<String> _resolveSubreddits(FilterState? filters) {
    // Manual subreddits (e.g. from topic presets) always take priority
    final manual = filters?.redditSubreddits ?? [];
    if (manual.isNotEmpty) return manual;

    final category = filters?.category ?? FeedCategory.all;
    if (category != FeedCategory.all) {
      return _categorySubreddits[category] ?? ['popular'];
    }

    // India region with no category: add India-specific subreddits
    if (filters?.region == FeedRegion.india) {
      return ['india', 'IndiaSpeaks', 'Indiatechnology', 'popular'];
    }

    return []; // empty = r/popular default
  }

  Future<List<TrendItem>> fetchTrending({FilterState? filters}) async {
    final subreddits = _resolveSubreddits(filters);

    List<TrendItem> items;
    if (subreddits.isEmpty) {
      // Default: r/popular hot feed
      items = await _fetchSubreddit('popular', filters: filters, limit: 25);
    } else {
      // Fetch each subreddit in parallel, merge, sort by score
      final results = await Future.wait(
        subreddits.map((sub) => _fetchSubreddit(sub, filters: filters, limit: 15)
            .catchError((_) => <TrendItem>[])),
      );
      items = results.expand((i) => i).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    }

    if (filters != null && filters.minRedditUpvotes > 0) {
      items = items
          .where((i) => (i.score ?? 0) >= filters.minRedditUpvotes)
          .toList();
    }
    return items;
  }

  Future<List<TrendItem>> _fetchSubreddit(
    String subreddit, {
    FilterState? filters,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (filters?.safeSearch == true) params['include_over_18'] = '0';

    final uri = Uri.parse('$_baseUrl/r/$subreddit/hot.json')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
          'Reddit API error ${response.statusCode}: ${response.body}');
    }
    return _parseItems(response.body);
  }

  Future<List<TrendItem>> search(String query, {FilterState? filters}) async {
    final params = <String, String>{
      'q': query,
      'sort': 'relevance',
      'limit': '20',
      't': filters != null ? _redditTime(filters.dateFilter) : 'day',
    };
    if (filters?.safeSearch == true) params['include_over_18'] = '0';

    final uri = Uri.parse('$_baseUrl/search.json')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'Reddit search error ${response.statusCode}: ${response.body}');
    }

    var items = _parseItems(response.body);
    if (filters != null && filters.minRedditUpvotes > 0) {
      items = items
          .where((i) => (i.score ?? 0) >= filters.minRedditUpvotes)
          .toList();
    }
    return items;
  }

  List<TrendItem> _parseItems(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final dataNode = data['data'] as Map<String, dynamic>?;
    final children = dataNode?['children'] as List<dynamic>? ?? [];

    return children.map((child) {
      final post = child['data'] as Map<String, dynamic>? ?? {};
      final thumbnail = _extractThumbnail(post);
      final permalink = post['permalink'] as String? ?? '';
      final score = (post['score'] as num?)?.toInt();

      final subredditName = post['subreddit'] as String? ?? 'unknown';
      return TrendItem(
        id: 'rd_${post['id'] ?? permalink.hashCode}',
        title: post['title'] as String? ?? '',
        description: post['selftext'] as String?,
        thumbnailUrl: thumbnail,
        url: 'https://www.reddit.com$permalink',
        source: TrendSource.reddit,
        author: post['author'] as String?,
        publishedAt: _parseCreated(post['created_utc']),
        score: score,
        sourceName: 'r/$subredditName',
        trendingReason: 'Hot in r/$subredditName',
      );
    }).toList();
  }

  // ── Typed methods returning RedditPost ─────────────────────────────────────

  Future<List<RedditPost>> fetchHotPosts({FilterState? filters}) async {
    final params = <String, String>{'limit': '20'};
    if (filters?.safeSearch == true) params['include_over_18'] = '0';

    final uri = Uri.parse('$_baseUrl/r/popular/hot.json')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'Reddit API error ${response.statusCode}: ${response.body}');
    }

    var posts = _parsePostItems(response.body);
    if (filters != null && filters.minRedditUpvotes > 0) {
      posts = posts.where((p) => p.ups >= filters.minRedditUpvotes).toList();
    }
    return posts;
  }

  Future<List<RedditPost>> searchPosts(String query,
      {FilterState? filters}) async {
    final params = <String, String>{
      'q': query,
      'sort': 'relevance',
      'limit': '20',
      't': filters != null ? _redditTime(filters.dateFilter) : 'day',
    };
    if (filters?.safeSearch == true) params['include_over_18'] = '0';

    final uri = Uri.parse('$_baseUrl/search.json')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'Reddit search error ${response.statusCode}: ${response.body}');
    }

    var posts = _parsePostItems(response.body);
    if (filters != null && filters.minRedditUpvotes > 0) {
      posts = posts.where((p) => p.ups >= filters.minRedditUpvotes).toList();
    }
    return posts;
  }

  List<RedditPost> _parsePostItems(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final dataNode = data['data'] as Map<String, dynamic>?;
    final children = dataNode?['children'] as List<dynamic>? ?? [];

    return children.map((child) {
      final post = child['data'] as Map<String, dynamic>? ?? {};
      final thumbnail = _extractThumbnail(post);
      final permalink = post['permalink'] as String? ?? '';

      return RedditPost(
        id: post['id'] as String? ?? '',
        title: post['title'] as String? ?? '',
        subreddit: post['subreddit'] as String? ?? 'unknown',
        ups: (post['score'] as num?)?.toInt() ?? 0,
        numComments: (post['num_comments'] as num?)?.toInt() ?? 0,
        url: 'https://www.reddit.com$permalink',
        author: post['author'] as String? ?? '[deleted]',
        thumbnailUrl: thumbnail,
      );
    }).toList();
  }

  String? _extractThumbnail(Map<String, dynamic> post) {
    final preview = post['preview'] as Map<String, dynamic>?;
    if (preview != null) {
      final images = preview['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        final source = (images.first as Map<String, dynamic>?)?['source']
            as Map<String, dynamic>?;
        final url = source?['url'] as String?;
        if (url != null) return url.replaceAll('&amp;', '&');
      }
    }
    final rawThumb = post['thumbnail'] as String?;
    if (rawThumb != null && rawThumb.startsWith('http')) return rawThumb;
    return null;
  }

  DateTime _parseCreated(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(
      (value as num).toInt() * 1000,
    );
  }
}
