import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webfeed_revised/webfeed_revised.dart';
import 'package:html/parser.dart' show parse;
import '../models/filter_state.dart';
import '../models/trend_item.dart';
import '../models/news_article.dart';

// ── Base sources (always available, shown when region=global, category=all) ──

const _rssSources = [
  ('BBC News',       'https://feeds.bbci.co.uk/news/rss.xml'),
  ('Times of India', 'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'),
  ('NDTV',           'https://feeds.feedburner.com/ndtvnews-top-stories'),
  ('The Hindu',      'https://www.thehindu.com/feeder/default.rss'),
  ('Al Jazeera',     'https://www.aljazeera.com/xml/rss/all.xml'),
  ('Reuters',        'https://feeds.reuters.com/reuters/topNews'),
  ('India Today',    'https://www.indiatoday.in/rss/home'),
];

// ── Indian outlets — used when region = india ─────────────────────────────────

const _indiaOutlets = {'Times of India', 'NDTV', 'The Hindu', 'India Today'};

// ── Category-specific RSS feeds (global context) ─────────────────────────────

const _categoryFeeds = <FeedCategory, List<(String, String)>>{
  FeedCategory.tech: [
    ('BBC Technology',  'https://feeds.bbci.co.uk/news/technology/rss.xml'),
    ('Reuters Tech',    'https://feeds.reuters.com/reuters/technologyNews'),
    ('Times of India',  'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'),
  ],
  FeedCategory.finance: [
    ('BBC Business',     'https://feeds.bbci.co.uk/news/business/rss.xml'),
    ('Reuters Business', 'https://feeds.reuters.com/reuters/businessNews'),
    ('Times of India',   'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'),
  ],
  FeedCategory.entertainment: [
    ('BBC Entertainment', 'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml'),
    ('India Today',       'https://www.indiatoday.in/rss/home'),
    ('Al Jazeera',        'https://www.aljazeera.com/xml/rss/all.xml'),
  ],
  FeedCategory.gaming: [
    ('BBC Technology',   'https://feeds.bbci.co.uk/news/technology/rss.xml'),
    ('Reuters Tech',     'https://feeds.reuters.com/reuters/technologyNews'),
    ('Times of India',   'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'),
  ],
  FeedCategory.startups: [
    ('BBC Technology',   'https://feeds.bbci.co.uk/news/technology/rss.xml'),
    ('Reuters Business', 'https://feeds.reuters.com/reuters/businessNews'),
    ('Times of India',   'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'),
  ],
};

class NewsService {
  DateTime? _fromDate(DateFilter dateFilter) {
    final now = DateTime.now().toUtc();
    switch (dateFilter) {
      case DateFilter.last24h:
        return now.subtract(const Duration(hours: 24));
      case DateFilter.lastWeek:
        return now.subtract(const Duration(days: 7));
      case DateFilter.lastMonth:
        return now.subtract(const Duration(days: 30));
      case DateFilter.any:
        return null;
    }
  }

  bool _passesDateFilter(DateTime publishedAt, FilterState? filters) {
    if (filters == null || filters.dateFilter == DateFilter.any) return true;
    final from = _fromDate(filters.dateFilter);
    return from == null || publishedAt.isAfter(from);
  }

  /// Robustly strips HTML tags and decodes entities using the 'html' package.
  String? _cleanHtml(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final document = parse(raw);
      final String parsedString = parse(document.body?.text ?? '').documentElement?.text ?? '';
      return parsedString.trim().replaceAll(RegExp(r'\s+'), ' ');
    } catch (_) {
      return raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
  }

  /// Resolves the feed list to fetch based on region and category.
  List<(String, String)> _resolveSources(FilterState? filters) {
    final region = filters?.region ?? FeedRegion.global;
    final category = filters?.category ?? FeedCategory.all;
    final enabledSources = filters?.resolvedNewsSources;

    // India mode: always prioritize Indian outlets regardless of category
    if (region == FeedRegion.india) {
      final indiaSources = _rssSources
          .where((s) => _indiaOutlets.contains(s.$1))
          .toList();
      if (enabledSources != null) {
        return indiaSources.where((s) => enabledSources.contains(s.$1)).toList();
      }
      return indiaSources;
    }

    // Global + specific category: use category-specific feeds
    if (category != FeedCategory.all) {
      final catFeeds = _categoryFeeds[category] ?? _rssSources.toList();
      if (enabledSources != null) {
        return catFeeds.where((s) => enabledSources.contains(s.$1)).toList();
      }
      return catFeeds;
    }

    // Global + all categories: use all enabled base sources
    if (enabledSources == null) return _rssSources.toList();
    return _rssSources.where((s) => enabledSources.contains(s.$1)).toList();
  }

  Future<List<TrendItem>> fetchTrending({
    String? country,
    FilterState? filters,
  }) async {
    return _fetchRssFeeds(filters: filters).catchError((_) => <TrendItem>[]);
  }

  Future<List<TrendItem>> search(String query, {FilterState? filters}) async {
    final all = await _fetchRssFeeds(filters: filters)
        .catchError((_) => <TrendItem>[]);
    final q = query.toLowerCase();
    return all
        .where((i) =>
            i.title.toLowerCase().contains(q) ||
            (i.description?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // ── RSS Feeds ──────────────────────────────────────────────────────────────

  Future<List<TrendItem>> _fetchRssFeeds({FilterState? filters}) async {
    final sources = _resolveSources(filters);

    final responses = await Future.wait(
      sources.map((s) => _fetchOneFeed(s.$1, s.$2)),
    );

    final items = responses.expand((i) => i).toList();
    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return items
        .where((i) => _passesDateFilter(i.publishedAt, filters))
        .toList();
  }

  Future<List<TrendItem>> _fetchOneFeed(
      String sourceName, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'UniTrend/1.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      // Always decode as UTF-8 — http defaults to latin-1 which garbles
      // non-ASCII characters from Indian and Arabic news sources.
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final feed = RssFeed.parse(body);
      return (feed.items ?? [])
          .where((item) => item.title != null && item.link != null)
          .map((item) {
            final itemUrl = item.link ?? '';
            final pubDate = item.pubDate ?? DateTime.now();
            final thumb = item.enclosure?.url;
            final description = _cleanHtml(item.description);

            // Decode HTML entities in URLs (e.g. &amp; → &) from some RSS feeds
            final cleanUrl = itemUrl.replaceAll('&amp;', '&');
            return TrendItem(
              id: 'rss_${cleanUrl.hashCode}',
              title: _cleanHtml(item.title) ?? item.title!,
              description: description?.isNotEmpty == true ? description : null,
              thumbnailUrl: thumb,
              url: cleanUrl,
              source: TrendSource.news,
              author: item.author,
              publishedAt: pubDate,
              sourceName: sourceName,
              trendingReason: 'Breaking: $sourceName',
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Typed methods (kept for compatibility) ─────────────────────────────────

  Future<List<NewsArticle>> fetchTopHeadlines({
    String? country,
    FilterState? filters,
  }) async {
    final items = await _fetchRssFeeds(filters: filters);
    return items
        .map((i) => NewsArticle(
              title: i.title,
              sourceName: i.sourceName ?? '',
              urlToImage: i.thumbnailUrl,
              publishedAt: i.publishedAt,
              url: i.url,
              description: i.description,
            ))
        .toList();
  }

  Future<List<NewsArticle>> searchArticles(String query,
      {FilterState? filters}) async {
    final items = await search(query, filters: filters);
    return items
        .map((i) => NewsArticle(
              title: i.title,
              sourceName: i.sourceName ?? '',
              urlToImage: i.thumbnailUrl,
              publishedAt: i.publishedAt,
              url: i.url,
              description: i.description,
            ))
        .toList();
  }
}
