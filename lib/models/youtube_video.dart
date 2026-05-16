class YouTubeVideo {
  final String videoId;
  final String title;
  final String? thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final String channelTitle;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    this.thumbnailUrl,
    required this.viewCount,
    required this.likeCount,
    required this.channelTitle,
  });

  String get url => 'https://www.youtube.com/watch?v=$videoId';

  String get formattedViews {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    }
    if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(0)}K views';
    }
    return '$viewCount views';
  }
}
