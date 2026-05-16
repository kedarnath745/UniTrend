import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/trend_item.dart';

class TechService {
  final http.Client _client = http.Client();

  /// Fetches Top Stories from Hacker News via Algolia API
  Future<List<TrendItem>> fetchHackerNews() async {
    try {
      // Use Algolia for HN to get sorted, recent, and high-quality results in one call
      final url = 'https://hn.algolia.com/api/v1/search?tags=front_page';
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body);
      final hits = data['hits'] as List<dynamic>;

      return hits.map((hit) {
        final createdAt = DateTime.parse(hit['created_at'] as String);
        final score = hit['points'] as int? ?? 0;
        
        return TrendItem(
          id: 'hn_${hit['objectID']}',
          title: hit['title'] as String? ?? 'No Title',
          url: hit['url'] as String? ?? 'https://news.ycombinator.com/item?id=${hit['objectID']}',
          source: TrendSource.hackerNews,
          author: hit['author'] as String?,
          publishedAt: createdAt,
          score: score,
          sourceName: 'Hacker News',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches Trending Products from Product Hunt (RSS)
  Future<List<TrendItem>> fetchProductHunt() async {
    try {
      // Product Hunt doesn't have a public free API without auth, so we use their RSS
      final url = 'https://www.producthunt.com/feed';
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) return [];

      final document = parse(response.body);
      final items = document.querySelectorAll('entry');

      return items.map((entry) {
        final title = entry.querySelector('title')?.text ?? 'Unknown Product';
        final link = entry.querySelector('link')?.attributes['href'] ?? '';
        final published = DateTime.tryParse(entry.querySelector('published')?.text ?? '') ?? DateTime.now();
        final content = entry.querySelector('content')?.text ?? '';
        
        // Product Hunt RSS doesn't give scores, so we assign a baseline
        return TrendItem(
          id: 'ph_${link.hashCode}',
          title: title,
          description: _stripHtml(content),
          url: link,
          source: TrendSource.productHunt,
          publishedAt: published,
          score: 50, // Baseline score
          sourceName: 'Product Hunt',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches Top Articles from Dev.to
  Future<List<TrendItem>> fetchDevTo() async {
    try {
      final url = 'https://dev.to/api/articles?top=1';
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) return [];
      
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((article) {
        final publishedAt = DateTime.parse(article['published_at'] as String);
        final score = (article['public_reactions_count'] as int? ?? 0) + 
                     (article['comments_count'] as int? ?? 0);
        
        return TrendItem(
          id: 'devto_${article['id']}',
          title: article['title'] as String,
          description: article['description'] as String?,
          thumbnailUrl: article['cover_image'] as String?,
          url: article['url'] as String,
          source: TrendSource.devTo,
          author: article['user']?['name'] as String?,
          publishedAt: publishedAt,
          score: score,
          sourceName: 'Dev.to',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _stripHtml(String html) {
    return parse(html).body?.text.trim() ?? '';
  }
}
