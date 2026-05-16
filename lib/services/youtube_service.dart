import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/filter_state.dart';
import '../models/trend_item.dart';
import '../models/youtube_video.dart';

// YouTube video category IDs for each FeedCategory
const _ytCategoryIds = <FeedCategory, String>{
  FeedCategory.tech:          '28', // Science & Technology
  FeedCategory.gaming:        '20', // Gaming
  FeedCategory.entertainment: '24', // Entertainment
  FeedCategory.finance:       '25', // News & Politics (closest match)
  FeedCategory.startups:      '28', // Science & Technology
};

// Human-readable category labels for trendingReason
const _ytCategoryLabels = <FeedCategory, String>{
  FeedCategory.tech:          'Tech',
  FeedCategory.gaming:        'Gaming',
  FeedCategory.entertainment: 'Entertainment',
  FeedCategory.finance:       'Finance',
  FeedCategory.startups:      'Startups',
};

class YouTubeService {
  static const _baseUrl = 'https://www.googleapis.com/youtube/v3';

  String get _apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  String get _regionCode {
    final configured = dotenv.env['YOUTUBE_REGION_CODE']?.trim().toUpperCase();
    if (configured != null && configured.isNotEmpty) return configured;

    for (final locale in ui.PlatformDispatcher.instance.locales) {
      final code = locale.countryCode?.trim().toUpperCase();
      if (code != null && code.isNotEmpty) return code;
    }

    // Avoid a hard US fallback; make the region explicit in .env when needed.
    return 'IN';
  }

  bool _isPlayableVideo(Map<String, dynamic> item, String regionCode) {
    final status = item['status'] as Map<String, dynamic>? ?? {};
    if (status['embeddable'] == false) return false;
    if (status['privacyStatus'] != 'public') return false;

    final contentDetails = item['contentDetails'] as Map<String, dynamic>? ?? {};
    final regionRestriction =
        contentDetails['regionRestriction'] as Map<String, dynamic>?;
    if (regionRestriction == null) return true;

    final blocked = (regionRestriction['blocked'] as List?)?.cast<String>();
    if (blocked != null && blocked.contains(regionCode)) return false;

    final allowed = (regionRestriction['allowed'] as List?)?.cast<String>();
    if (allowed != null && !allowed.contains(regionCode)) return false;

    return true;
  }

  Map<String, dynamic>? _bestThumbnail(Map<String, dynamic> snippet) {
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    return (thumbnails['maxres'] ??
            thumbnails['standard'] ??
            thumbnails['high'] ??
            thumbnails['medium'] ??
            thumbnails['default'])
        as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> _fetchVideoDetails(
    List<String> ids, {
    String? regionCode,
  }) async {
    if (ids.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
      'part': 'snippet,statistics,status,contentDetails',
      'id': ids.join(','),
      'regionCode': regionCode ?? _regionCode,
      'maxResults': '${ids.length}',
      'key': _apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('YouTube API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  String? _publishedAfter(DateFilter dateFilter) {
    final now = DateTime.now().toUtc();
    switch (dateFilter) {
      case DateFilter.last24h:
        return now.subtract(const Duration(hours: 24)).toIso8601String();
      case DateFilter.lastWeek:
        return now.subtract(const Duration(days: 7)).toIso8601String();
      case DateFilter.lastMonth:
        return now.subtract(const Duration(days: 30)).toIso8601String();
      case DateFilter.any:
        return null;
    }
  }

  /// Resolves the region code for YouTube trending fetch.
  /// India mode → 'IN'; Global mode → 'US' (worldwide trending);
  /// explicit code always wins.
  String _resolveRegion(String? explicitCode, FilterState? filters) {
    if (explicitCode != null) return explicitCode;
    if (filters?.region == FeedRegion.india) return 'IN';
    if (filters?.region == FeedRegion.global) return 'US';
    return _regionCode; // device locale (no filter set)
  }

  /// Resolves the YouTube video category ID from filters.
  /// Manual youtubeCategoryId takes priority; otherwise derives from FeedCategory.
  String? _resolveCategoryId(FilterState? filters) {
    if (filters?.youtubeCategoryId != null) return filters!.youtubeCategoryId;
    final cat = filters?.category ?? FeedCategory.all;
    return _ytCategoryIds[cat]; // null for FeedCategory.all
  }

  Future<List<TrendItem>> fetchTrending({
    String? regionCode,
    FilterState? filters,
  }) async {
    final region = _resolveRegion(regionCode, filters);
    final categoryId = _resolveCategoryId(filters);
    final category = filters?.category ?? FeedCategory.all;
    final reasonLabel = category != FeedCategory.all
        ? _ytCategoryLabels[category] ?? 'YouTube'
        : (filters?.region == FeedRegion.india ? 'India' : 'Global');

    final params = <String, String>{
      'part': 'snippet,statistics,status,contentDetails',
      'chart': 'mostPopular',
      'regionCode': region,
      'maxResults': '30',
      'key': _apiKey,
    };
    if (categoryId != null) params['videoCategoryId'] = categoryId;

    final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: params);

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('YouTube API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;

    var result = items
        .where((item) {
          return _isPlayableVideo(item as Map<String, dynamic>, region);
        })
        .map((item) {
          final snippet = item['snippet'] as Map<String, dynamic>;
          final stats = item['statistics'] as Map<String, dynamic>? ?? {};
          final thumbnail = _bestThumbnail(snippet);

          return TrendItem(
            id: 'yt_${item['id']}',
            title: snippet['title'] as String,
            description: snippet['description'] as String?,
            thumbnailUrl: thumbnail?['url'] as String?,
            url: 'https://www.youtube.com/watch?v=${item['id']}',
            source: TrendSource.youtube,
            author: snippet['channelTitle'] as String?,
            publishedAt:
                DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ??
                    DateTime.now(),
            score: int.tryParse(stats['viewCount']?.toString() ?? ''),
            sourceName: snippet['channelTitle'] as String?,
            trendingReason: 'Trending in $reasonLabel',
          );
        })
        .toList();

    if (filters != null && filters.minYoutubeViews > 0) {
      result = result
          .where((i) => (i.score ?? 0) >= filters.minYoutubeViews)
          .toList();
    }
    return result;
  }

  Future<List<TrendItem>> search(String query, {FilterState? filters}) async {
    final region = _regionCode;
    final params = <String, String>{
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': '20',
      'order': 'relevance',
      'key': _apiKey,
    };

    if (filters != null) {
      if (filters.safeSearch) params['safeSearch'] = 'strict';
      final after = _publishedAfter(filters.dateFilter);
      if (after != null) params['publishedAfter'] = after;
    }

    final uri =
        Uri.parse('$_baseUrl/search').replace(queryParameters: params);

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('YouTube search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    final orderedIds = items
        .map((item) => (item['id'] as Map<String, dynamic>)['videoId'] as String?)
        .whereType<String>()
        .toList();

    final detailedItems =
        await _fetchVideoDetails(orderedIds, regionCode: region);
    final byId = {
      for (final item in detailedItems) item['id'] as String: item,
    };

    var result = orderedIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .where((item) => _isPlayableVideo(item, region))
        .map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final stats = item['statistics'] as Map<String, dynamic>? ?? {};
      final videoId = item['id'] as String;
      final thumbnail = _bestThumbnail(snippet);

      return TrendItem(
        id: 'yt_$videoId',
        title: snippet['title'] as String,
        description: snippet['description'] as String?,
        thumbnailUrl: thumbnail?['url'] as String?,
        url: 'https://www.youtube.com/watch?v=$videoId',
        source: TrendSource.youtube,
        author: snippet['channelTitle'] as String?,
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ??
                DateTime.now(),
        score: int.tryParse(stats['viewCount']?.toString() ?? ''),
        sourceName: snippet['channelTitle'] as String?,
      );
    }).toList();

    if (filters != null && filters.minYoutubeViews > 0) {
      result = result
          .where((item) => (item.score ?? 0) >= filters.minYoutubeViews)
          .toList();
    }

    return result;
  }

  // ── Typed methods returning YouTubeVideo ───────────────────────────────────

  Future<List<YouTubeVideo>> fetchTrendingVideos({
    String? regionCode,
    FilterState? filters,
  }) async {
    final region = regionCode ?? _regionCode;
    final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
      'part': 'snippet,statistics,status,contentDetails',
      'chart': 'mostPopular',
      'regionCode': region,
      'maxResults': '20',
      'key': _apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('YouTube API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;

    var result = items
        .where((item) => _isPlayableVideo(item as Map<String, dynamic>, region))
        .map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final stats = item['statistics'] as Map<String, dynamic>? ?? {};
      final thumb = _bestThumbnail(snippet);

      return YouTubeVideo(
        videoId: item['id'] as String,
        title: snippet['title'] as String,
        thumbnailUrl: thumb?['url'] as String?,
        viewCount: int.tryParse(stats['viewCount']?.toString() ?? '') ?? 0,
        likeCount: int.tryParse(stats['likeCount']?.toString() ?? '') ?? 0,
        channelTitle: snippet['channelTitle'] as String? ?? '',
      );
    }).toList();

    if (filters != null && filters.minYoutubeViews > 0) {
      result =
          result.where((v) => v.viewCount >= filters.minYoutubeViews).toList();
    }
    return result;
  }

  Future<List<YouTubeVideo>> searchVideos(String query,
      {FilterState? filters}) async {
    final region = _regionCode;
    final searchParams = <String, String>{
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': '20',
      'order': 'relevance',
      'key': _apiKey,
    };

    if (filters != null) {
      if (filters.safeSearch) searchParams['safeSearch'] = 'strict';
      final after = _publishedAfter(filters.dateFilter);
      if (after != null) searchParams['publishedAfter'] = after;
    }

    final searchUri =
        Uri.parse('$_baseUrl/search').replace(queryParameters: searchParams);

    final searchResp = await http.get(searchUri);
    if (searchResp.statusCode != 200) {
      throw Exception('YouTube search error: ${searchResp.statusCode}');
    }

    final searchData = jsonDecode(searchResp.body) as Map<String, dynamic>;
    final searchItems = searchData['items'] as List<dynamic>;
    if (searchItems.isEmpty) return [];

    final orderedIds = searchItems
        .map((item) => (item['id'] as Map<String, dynamic>)['videoId'] as String?)
        .whereType<String>()
        .toList();

    final detailedItems =
        await _fetchVideoDetails(orderedIds, regionCode: region);
    final byId = {
      for (final item in detailedItems) item['id'] as String: item,
    };

    var result = orderedIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .where((item) => _isPlayableVideo(item, region))
        .map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final stats = item['statistics'] as Map<String, dynamic>? ?? {};
      final thumb = _bestThumbnail(snippet);

      return YouTubeVideo(
        videoId: item['id'] as String,
        title: snippet['title'] as String,
        thumbnailUrl: thumb?['url'] as String?,
        viewCount: int.tryParse(stats['viewCount']?.toString() ?? '') ?? 0,
        likeCount: int.tryParse(stats['likeCount']?.toString() ?? '') ?? 0,
        channelTitle: snippet['channelTitle'] as String? ?? '',
      );
    }).toList();

    if (filters != null && filters.minYoutubeViews > 0) {
      result =
          result.where((v) => v.viewCount >= filters.minYoutubeViews).toList();
    }
    return result;
  }
}
