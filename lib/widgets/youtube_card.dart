import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/youtube_video.dart';

class YouTubeCard extends StatelessWidget {
  final YouTubeVideo video;

  const YouTubeCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _openUrl(video.url),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(left: 12, bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            _buildThumbnail(theme),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.channelTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFF5722),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          video.formattedViews,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    if (video.thumbnailUrl == null) {
      return Container(
        height: 112,
        color: theme.colorScheme.surfaceContainerHigh,
        child: const Icon(Icons.play_circle_outline, size: 40, color: Colors.grey),
      );
    }
    return CachedNetworkImage(
      imageUrl: video.thumbnailUrl!,
      height: 112,
      width: 200,
      memCacheHeight: 224,
      memCacheWidth: 400,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: 112,
        color: theme.colorScheme.surfaceContainerHigh,
      ),
      errorWidget: (_, _, _) => Container(
        height: 112,
        color: theme.colorScheme.surfaceContainerHigh,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
