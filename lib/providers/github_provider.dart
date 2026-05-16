import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trend_item.dart';
import 'feed_provider.dart';
import 'filter_provider.dart';

final githubTrendingProvider = FutureProvider<List<TrendItem>>((ref) {
  final filters = ref.watch(filterProvider);
  return ref.watch(gitHubServiceProvider).fetchTrending(filters: filters);
});
