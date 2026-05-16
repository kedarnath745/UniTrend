import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_article.dart';
import 'feed_provider.dart';
import 'filter_provider.dart';

final newsTrendingProvider = FutureProvider<List<NewsArticle>>((ref) {
  final filters = ref.watch(filterProvider);
  return ref
      .watch(newsServiceProvider)
      .fetchTopHeadlines(filters: filters);
});
