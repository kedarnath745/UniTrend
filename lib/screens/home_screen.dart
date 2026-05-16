import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/scroll_to_top_provider.dart';
import '../providers/youtube_provider.dart';
import '../providers/reddit_provider.dart';
import '../providers/news_provider.dart';
import '../providers/github_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/user_provider.dart';
import '../providers/groq_provider.dart';
import '../providers/watchlist_provider.dart';
import '../models/trend_item.dart';
import '../models/youtube_video.dart';
import '../widgets/youtube_card.dart';
import '../widgets/reddit_post_tile.dart';
import '../widgets/news_article_tile.dart';
import '../widgets/trend_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/floating_orbs_background.dart';
import '../widgets/gradient_skeleton.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

const _ytRed = Color(0xFFFF0000);
const _redditOrange = Color(0xFFFF4500);
const _newsBlue = Color(0xFF1E88E5);
const _githubGreen = Color(0xFF238636);
const _accent = Color(0xFFFF5722);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 300;
      if (show != _showFab) setState(() => _showFab = show);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollCtrl.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScrollToTopProvider, (prev, next) => _scrollToTop());

    final ytAsync = ref.watch(youtubeTrendingProvider);
    final rdAsync = ref.watch(redditTrendingProvider);
    final newsAsync = ref.watch(newsTrendingProvider);
    final ghAsync = ref.watch(githubTrendingProvider);
    final feedAsync = ref.watch(feedProvider);
    final filters = ref.watch(filterProvider);

    final hasActiveFilters = filters.hasActiveFilters;

    return FloatingOrbsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: AnimatedSlide(
          offset: _showFab ? Offset.zero : const Offset(0, 2),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showFab ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
        ),
        body: RefreshIndicator(
          color: _accent,
          onRefresh: () async {
            ref.invalidate(feedProvider);
            ref.invalidate(youtubeTrendingProvider);
            ref.invalidate(redditTrendingProvider);
            ref.invalidate(newsTrendingProvider);
            ref.invalidate(githubTrendingProvider);
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A0A0F).withValues(alpha: 0.6)
                          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.accentGradient.createShader(bounds),
                      child: const Icon(Icons.bolt,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 6),
                    _ShimmerTitle(),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Filters',
                    icon: Badge(
                      isLabelVisible: hasActiveFilters,
                      backgroundColor: _accent,
                      child: const Icon(Icons.tune_outlined),
                    ),
                    onPressed: () => showFilterSheet(context),
                  ),
                  _ProfileButton(),
                ],
              ),

              // ── AI Trend Digest ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: feedAsync.maybeWhen(
                  data: (items) => _TrendDigestCard(feedItems: items),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),

              // ── Watchlist ─────────────────────────────────────────────────
              const SliverToBoxAdapter(child: _WatchlistSection()),

              // ── YouTube section ───────────────────────────────────────────
              if (filters.youtubeEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.play_circle_filled,
                  label: 'Trending on YouTube',
                  color: _ytRed,
                ),
                SliverToBoxAdapter(
                  child: ytAsync.when(
                    loading: () => const _YouTubeSkeletonList(),
                    error: (e, _) => _SectionError(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(youtubeTrendingProvider),
                    ),
                    data: (videos) => _YouTubeList(videos: videos),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // ── Reddit section ────────────────────────────────────────────
              if (filters.redditEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.reddit,
                  label: 'Hot on Reddit',
                  color: _redditOrange,
                ),
                rdAsync.when(
                  loading: () => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => const GradientSkeletonPost(),
                      childCount: 5,
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _SectionError(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(redditTrendingProvider),
                    ),
                  ),
                  data: (posts) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Column(
                        children: [
                          RedditPostTile(post: posts[i]),
                          if (i < posts.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                        ],
                      ),
                      childCount: posts.length.clamp(0, 15),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // ── News section ──────────────────────────────────────────────
              if (filters.newsEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.newspaper,
                  label: 'Top Headlines',
                  color: _newsBlue,
                ),
                newsAsync.when(
                  loading: () => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => const GradientSkeletonPost(),
                      childCount: 5,
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _SectionError(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(newsTrendingProvider),
                    ),
                  ),
                  data: (articles) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Column(
                        children: [
                          NewsArticleTile(article: articles[i]),
                          if (i < articles.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                        ],
                      ),
                      childCount: articles.length.clamp(0, 15),
                    ),
                  ),
                ),
              ],

              // ── GitHub section ────────────────────────────────────────────
              if (filters.githubEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.code_rounded,
                  label: 'Trending on GitHub',
                  color: _githubGreen,
                ),
                ghAsync.when(
                  loading: () => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => const GradientSkeletonPost(),
                      childCount: 5,
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _SectionError(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(githubTrendingProvider),
                    ),
                  ),
                  data: (repos) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => TrendCard(item: repos[i]),
                      childCount: repos.length.clamp(0, 10),
                    ),
                  ),
                ),
              ],

              if (filters.hackerNewsEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.forum_rounded,
                  label: 'Top on Hacker News',
                  color: const Color(0xFFFF6600),
                ),
                _trendSourceSection(
                  ref: ref,
                  asyncItems: feedAsync,
                  source: TrendSource.hackerNews,
                ),
              ],

              if (filters.productHuntEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.rocket_launch_rounded,
                  label: 'Trending on Product Hunt',
                  color: const Color(0xFFDA552F),
                ),
                _trendSourceSection(
                  ref: ref,
                  asyncItems: feedAsync,
                  source: TrendSource.productHunt,
                ),
              ],

              if (filters.devToEnabled) ...[
                _sectionHeader(
                  context,
                  icon: Icons.article_rounded,
                  label: 'Top on Dev.to',
                  color: const Color(0xFF111111),
                ),
                _trendSourceSection(
                  ref: ref,
                  asyncItems: feedAsync,
                  source: TrendSource.devTo,
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendSourceSection({
    required WidgetRef ref,
    required AsyncValue<List<TrendItem>> asyncItems,
    required TrendSource source,
  }) {
    return asyncItems.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, _) => const GradientSkeletonPost(),
          childCount: 3,
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: _SectionError(
          message: e.toString(),
          onRetry: () => ref.invalidate(feedProvider),
        ),
      ),
      data: (items) {
        final filtered =
            items.where((item) => item.source == source).take(10).toList();
        if (filtered.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No items available right now.'),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => TrendCard(item: filtered[i]),
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Trend Digest Card ─────────────────────────────────────────────────────

class _TrendDigestCard extends ConsumerWidget {
  final List<TrendItem> feedItems;
  const _TrendDigestCard({required this.feedItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digest = ref.watch(trendDigestProvider);
    final theme = Theme.of(context);
    final period = digest.period;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF5722).withValues(alpha: 0.08),
            const Color(0xFF7B61FF).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5722).withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'AI Trend Digest',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Period selector
              ...DigestPeriod.values.map((p) {
                final selected = p == period;
                return GestureDetector(
                  onTap: () =>
                      ref.read(trendDigestProvider.notifier).setPeriod(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? _accent.withValues(alpha: 0.6)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: selected
                            ? _accent
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 12),

          // ── Body ────────────────────────────────────────────────────────
          digest.value.when(
            // Empty = not yet generated
            data: (text) => text.isEmpty
                ? _GenerateButton(
                    onTap: () => ref
                        .read(trendDigestProvider.notifier)
                        .generate(feedItems, period),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => ref
                              .read(trendDigestProvider.notifier)
                              .generate(feedItems, period),
                          icon: Icon(Icons.refresh,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant),
                          label: Text(
                            'Refresh',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  SizedBox(width: 10),
                  Text('Analyzing trends…',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not generate digest. Tap to retry.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error),
                ),
                const SizedBox(height: 6),
                _GenerateButton(
                  label: 'Retry',
                  onTap: () => ref
                      .read(trendDigestProvider.notifier)
                      .generate(feedItems, period),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _GenerateButton({required this.onTap, this.label = 'Generate Digest'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer Title ─────────────────────────────────────────────────────────────

class _ShimmerTitle extends StatefulWidget {
  @override
  State<_ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<_ShimmerTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            Color(0xFFFF6B35),
            Color(0xFFE94B9C),
            Color(0xFF7B61FF),
            Color(0xFFE94B9C),
            Color(0xFFFF6B35),
          ],
          stops: [
            (_anim.value - 1).clamp(0.0, 1.0),
            (_anim.value - 0.5).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.5).clamp(0.0, 1.0),
            (_anim.value + 1).clamp(0.0, 1.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        child: const Text(
          'UniTrend',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// ── Profile button (shows guest badge when anonymous) ────────────────────────

class _ProfileButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authAsync = ref.watch(authStateProvider);

    final isGuest = authAsync.valueOrNull?.isAnonymous ?? false;

    final icon = userAsync.maybeWhen(
      data: (user) => user?.profilePicUrl != null
          ? CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(user!.profilePicUrl!),
            )
          : const Icon(Icons.account_circle_outlined),
      orElse: () => const Icon(Icons.account_circle_outlined),
    );

    return IconButton(
      tooltip: isGuest ? 'Guest — tap to sign in' : 'Profile',
      icon: isGuest
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.account_circle_outlined),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Guest',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1.2),
                    ),
                  ),
                ),
              ],
            )
          : icon,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
    );
  }
}

// ── YouTube horizontal list ──────────────────────────────────────────────────

class _YouTubeList extends StatelessWidget {
  final List<YouTubeVideo> videos;
  const _YouTubeList({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No videos found.')),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 12),
        itemCount: videos.length,
        itemBuilder: (_, i) => YouTubeCard(video: videos[i]),
      ),
    );
  }
}

// ── Gradient skeleton shimmer for YouTube ────────────────────────────────────

class _YouTubeSkeletonList extends StatelessWidget {
  const _YouTubeSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 12),
        itemCount: 5,
        itemBuilder: (_, _) => const GradientSkeletonCard(),
      ),
    );
  }
}

// ── Watchlist section ─────────────────────────────────────────────────────────

class _WatchlistSection extends ConsumerWidget {
  const _WatchlistSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywords = ref.watch(watchlistProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();

    final watchMap = ref.watch(watchlistFeedProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded,
                  size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(
                'Following',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: keywords.map((kw) {
                final count = watchMap.valueOrNull?[kw]?.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.track_changes_rounded,
                        size: 14, color: _accent),
                    label: Text(
                      '$kw${count > 0 ? ' ($count)' : ''}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor:
                        _accent.withValues(alpha: 0.08),
                    side: BorderSide(
                        color: _accent.withValues(alpha: 0.3)),
                    onPressed: () => _showKeywordSheet(
                        context, ref, kw,
                        watchMap.valueOrNull?[kw] ?? []),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showKeywordSheet(
    BuildContext context,
    WidgetRef ref,
    String keyword,
    List<TrendItem> items,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.track_changes_rounded,
                          color: _accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '#$keyword',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${items.length} match${items.length == 1 ? '' : 'es'}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      // Unfollow button
                      TextButton(
                        onPressed: () {
                          ref
                              .read(watchlistProvider.notifier)
                              .unfollow(keyword);
                          Navigator.pop(context);
                        },
                        child: const Text('Unfollow',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No current stories for "$keyword"',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check back when the feed refreshes.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: items.length,
                      itemBuilder: (_, i) => TrendCard(item: items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error widget ─────────────────────────────────────────────────────────────

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
