import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../services/link_opener.dart';

const _newsBlue = Color(0xFF1E88E5);

class NewsArticleTile extends StatelessWidget {
  final NewsArticle article;

  const NewsArticleTile({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => LinkOpener.open(context, article.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source
                  Text(
                    article.sourceName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _newsBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Headline
                  Text(
                    article.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Time
                  Text(
                    article.timeAgo,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Thumbnail
            if (article.urlToImage != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: article.urlToImage!,
                  width: 80,
                  height: 80,
                  memCacheWidth: 160,
                  memCacheHeight: 160,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
