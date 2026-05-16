class RedditPost {
  final String id;
  final String title;
  final String subreddit;
  final int ups;
  final int numComments;
  final String url;
  final String author;
  final String? thumbnailUrl;

  const RedditPost({
    required this.id,
    required this.title,
    required this.subreddit,
    required this.ups,
    required this.numComments,
    required this.url,
    required this.author,
    this.thumbnailUrl,
  });

  String get formattedUps {
    if (ups >= 1000) return '${(ups / 1000).toStringAsFixed(1)}K';
    return ups.toString();
  }

  String get formattedComments {
    if (numComments >= 1000) return '${(numComments / 1000).toStringAsFixed(1)}K';
    return numComments.toString();
  }
}
