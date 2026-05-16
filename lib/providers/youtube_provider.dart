import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_video.dart';
import 'feed_provider.dart';
import 'filter_provider.dart';

final youtubeTrendingProvider = FutureProvider<List<YouTubeVideo>>((ref) {
  final filters = ref.watch(filterProvider);
  return ref
      .watch(youTubeServiceProvider)
      .fetchTrendingVideos(filters: filters);
});
