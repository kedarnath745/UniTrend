class NewsArticle {
  final String title;
  final String sourceName;
  final String? urlToImage;
  final DateTime publishedAt;
  final String url;
  final String? description;

  const NewsArticle({
    required this.title,
    required this.sourceName,
    this.urlToImage,
    required this.publishedAt,
    required this.url,
    this.description,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
