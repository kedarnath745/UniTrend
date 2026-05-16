import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trend_item.dart';
import '../providers/user_provider.dart';
import 'sentiment_badge.dart';
import '../providers/feedback_provider.dart';
import '../providers/groq_provider.dart';
import '../providers/not_interested_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/link_opener.dart';

// Source accent colors
const _sourceColors = {
  TrendSource.youtube: Color(0xFFFF0000),
  TrendSource.reddit: Color(0xFFFF4500),
  TrendSource.news: Color(0xFF1565C0),
  TrendSource.github: Color(0xFF238636),
  TrendSource.hackerNews: Color(0xFFFF6600),
  TrendSource.productHunt: Color(0xFFDA552F),
  TrendSource.devTo: Color(0xFF0A0A0A),
};


class TrendCard extends ConsumerWidget {
  final TrendItem item;

  const TrendCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = _sourceColors[item.source] ?? Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final isBookmarked =
        bookmarksAsync.valueOrNull?.any((b) => b['id'] == item.id) ?? false;
    final feedback = ref.watch(feedbackProvider);
    final myFeedback = feedback[item.id]?.isPositive;

    return Dismissible(
      key: ValueKey('card_${item.id}'),
      direction: DismissDirection.horizontal,
      // Right swipe = bookmark (don't dismiss), Left swipe = not interested (dismiss)
      background: _SwipeBg(
        alignment: Alignment.centerLeft,
        color: const Color(0xFF22C55E),
        icon: isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
        label: isBookmarked ? 'Remove' : 'Bookmark',
      ),
      secondaryBackground: const _SwipeBg(
        alignment: Alignment.centerRight,
        color: Color(0xFFEF4444),
        icon: Icons.not_interested_rounded,
        label: 'Not Interested',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.mediumImpact();
          await _toggleBookmark(ref, isBookmarked, context);
          return false; // don't remove from list
        } else {
          HapticFeedback.lightImpact();
          ref.read(notInterestedProvider.notifier).dismiss(item.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Marked as not interested'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () =>
                      ref.read(notInterestedProvider.notifier).dismiss(''),
                ),
              ),
            );
          }
          return true;
        }
      },
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(recentlyViewedProvider.notifier).add(item);
          LinkOpener.open(context, item.url);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.thumbnailUrl != null) _buildThumbnail(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: source · name · trending reason ────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SourceChip(
                          label: item.sourceLabel, color: accentColor),
                      if (item.sentiment != TrendSentiment.neutral) ...[
                        const SizedBox(width: 5),
                        SentimentBadge(sentiment: item.sentiment),
                      ],
                      if (item.sourceName != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.sourceName!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (item.trendingReason != null) ...[
                        const SizedBox(width: 6),
                        _ReasonBadge(reason: item.trendingReason!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Title ─────────────────────────────────────────────────
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ── Description ───────────────────────────────────────────
                  if (item.description != null &&
                      item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // ── AI Summary ────────────────────────────────────────────
                  _AiSummarySection(item: item),

                  const SizedBox(height: 8),

                  // ── Meta + actions ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _buildMeta(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Thumbs up
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Relevant',
                          icon: Icon(
                            myFeedback == true
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                          ),
                          color: myFeedback == true
                              ? const Color(0xFF22C55E)
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            recordFeedback(ref, item, true);
                          },
                        ),
                      ),
                      // Thumbs down
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Not relevant',
                          icon: Icon(
                            myFeedback == false
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_outlined,
                          ),
                          color: myFeedback == false
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            recordFeedback(ref, item, false);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: const Icon(Icons.share_outlined),
                          color: theme.colorScheme.onSurfaceVariant,
                          onPressed: () =>
                              Share.share('${item.title}\n${item.url}'),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border_outlined,
                          ),
                          color: isBookmarked
                              ? accentColor
                              : theme.colorScheme.onSurfaceVariant,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _toggleBookmark(ref, isBookmarked, context);
                          },
                        ),
                      ),
                      // Follow topic button (uses primary tag)
                      _FollowButton(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),  // Card
    );   // Dismissible
  }

  Future<void> _toggleBookmark(
      WidgetRef ref, bool isCurrentlyBookmarked, BuildContext context) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    try {
      if (user != null) {
        final firestore = ref.read(firestoreServiceProvider);
        if (isCurrentlyBookmarked) {
          await firestore.removeBookmark(user.uid, item.id);
        } else {
          await firestore.addBookmark(user.uid, item.toMap());
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('guest_bookmarks');
        final List<dynamic> list = raw != null ? jsonDecode(raw) : [];
        if (isCurrentlyBookmarked) {
          list.removeWhere((e) => (e as Map)['id'] == item.id);
        } else {
          list.removeWhere((e) => (e as Map)['id'] == item.id);
          list.insert(0, item.toMap());
        }
        await prefs.setString('guest_bookmarks', jsonEncode(list));
      }
      ref.invalidate(bookmarksProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update bookmark')),
        );
      }
    }
  }

  Widget _buildThumbnail() {
    return CachedNetworkImage(
      imageUrl: item.thumbnailUrl!,
      height: 180,
      width: double.infinity,
      memCacheHeight: 360,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: 180,
        color: Colors.grey[200],
        child:
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => Container(
        height: 180,
        color: Colors.grey[200],
        child:
            const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  String _buildMeta() {
    final parts = <String>[];
    if (item.author != null) parts.add(item.author!);
    parts.add(_timeAgo(item.publishedAt));
    if (item.score != null) parts.add(_formatScore(item.score!, item.source));
    return parts.join(' \u00B7 ');
  }

  static String _formatScore(int score, TrendSource source) {
    final label = switch (source) {
      TrendSource.reddit => 'upvotes',
      TrendSource.github => 'stars',
      TrendSource.youtube => 'views',
      TrendSource.hackerNews => 'points',
      TrendSource.productHunt => 'votes',
      TrendSource.devTo => 'reactions',
      TrendSource.news => '',
    };
    final formatted = score >= 1000000
        ? '${(score / 1000000).toStringAsFixed(1)}M'
        : score >= 1000
            ? '${(score / 1000).toStringAsFixed(1)}K'
            : score.toString();
    return label.isEmpty ? formatted : '$formatted $label';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

}

// ── Swipe action background ───────────────────────────────────────────────────

class _SwipeBg extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 20 : 0,
        right: isLeft ? 0 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Summary ────────────────────────────────────────────────────────────────

class _AiSummarySection extends ConsumerWidget {
  final TrendItem item;
  const _AiSummarySection({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(summaryNotifierProvider)[item.id];
    final theme = Theme.of(context);

    if (state == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () =>
              ref.read(summaryNotifierProvider.notifier).fetch(item),
          icon: const Text('✨', style: TextStyle(fontSize: 12)),
          label: Text('AI Summary',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ),
      );
    }

    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          SizedBox(width: 8),
          Text('Summarizing…', style: TextStyle(fontSize: 11)),
        ]),
      ),
      data: (summary) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨ ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Text(summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface, height: 1.4)),
            ),
          ],
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(Icons.error_outline, size: 12, color: theme.colorScheme.error),
          const SizedBox(width: 4),
          Text('Summary failed. ',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.error)),
          GestureDetector(
            onTap: () {
              ref.read(summaryNotifierProvider.notifier).retry(item);
              ref.read(summaryNotifierProvider.notifier).fetch(item);
            },
            child: Text('Retry',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                )),
          ),
        ]),
      ),
    );
  }
}

// ── Trending reason badge ─────────────────────────────────────────────────────

class _ReasonBadge extends StatelessWidget {
  final String reason;
  const _ReasonBadge({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        reason,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Source chip ───────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SourceChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Follow topic button ───────────────────────────────────────────────────────

class _FollowButton extends ConsumerWidget {
  final TrendItem item;
  const _FollowButton({required this.item});

  // The keyword to follow: primary tag, or first word of the title
  String get _keyword {
    if (item.tags.isNotEmpty) return item.tags.first;
    return item.title.split(' ').first.toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_keyword.isEmpty) return const SizedBox.shrink();

    final kw = _keyword.trim().toLowerCase();
    final isFollowing = ref.watch(watchlistProvider).contains(kw);
    const teal = Color(0xFF14B8A6);

    return SizedBox(
      width: 30,
      height: 30,
      child: Tooltip(
        message: isFollowing ? 'Unfollow #$kw' : 'Follow #$kw',
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 16,
          icon: Icon(
            isFollowing
                ? Icons.track_changes_rounded
                : Icons.track_changes_outlined,
          ),
          color: isFollowing
              ? teal
              : Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
          onPressed: () {
            HapticFeedback.lightImpact();
            final notifier = ref.read(watchlistProvider.notifier);
            if (isFollowing) {
              notifier.unfollow(kw);
            } else {
              notifier.follow(kw);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Following #$kw'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => notifier.unfollow(kw),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
