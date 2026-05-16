import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reddit_post.dart';
import 'feed_provider.dart';
import 'filter_provider.dart';

final redditTrendingProvider = FutureProvider<List<RedditPost>>((ref) {
  final filters = ref.watch(filterProvider);
  return ref.watch(redditServiceProvider).fetchHotPosts(filters: filters);
});
