import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../models/filter_state.dart';
import '../models/trend_item.dart';
import '../providers/feed_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/scroll_to_top_provider.dart';
import '../providers/not_interested_provider.dart';
import '../providers/personalization_provider.dart';
import '../widgets/trend_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/sentiment_badge.dart';
import 'profile_screen.dart';

const _accent = Color(0xFFFF5722);

// Category metadata: label, icon, color
const _categoryMeta = <FeedCategory, (String, IconData, Color)>{
  FeedCategory.all:           ('All',           Icons.all_inclusive_outlined,   Color(0xFFFF5722)),
  FeedCategory.tech:          ('Tech',          Icons.memory_outlined,          Color(0xFF2196F3)),
  FeedCategory.finance:       ('Finance',       Icons.trending_up_rounded,      Color(0xFF4CAF50)),
  FeedCategory.entertainment: ('Entertainment', Icons.movie_outlined,           Color(0xFF9C27B0)),
  FeedCategory.gaming:        ('Gaming',        Icons.sports_esports_outlined,  Color(0xFF00BCD4)),
  FeedCategory.startups:      ('Startups',      Icons.rocket_launch_outlined,   Color(0xFFFF9800)),
};

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  TrendSource? _sourceFilter;
  String? _dismissedAlertTopic;
  String? _activeClusterTopic;
  String? _activeRadarClusterId;
  bool _globalMode = false;

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
    ref.listen(trendingScrollToTopProvider, (prev, next) => _scrollToTop());
    final feedAsync = _globalMode
        ? ref.watch(feedProvider)
        : ref.watch(personalizedFeedProvider);
    final notInterested = ref.watch(notInterestedProvider);
    final alert = ref.watch(clusterAlertProvider);
    final activeFilters = ref.watch(activeFeedFiltersProvider);
    final radarClusters = ref.watch(radarClustersProvider);
    final scheme = Theme.of(context).colorScheme;

    final enabledSources = {
      if (activeFilters.youtubeEnabled) TrendSource.youtube,
      if (activeFilters.redditEnabled) TrendSource.reddit,
      if (activeFilters.newsEnabled) TrendSource.news,
      if (activeFilters.githubEnabled) TrendSource.github,
      if (activeFilters.hackerNewsEnabled) TrendSource.hackerNews,
      if (activeFilters.productHuntEnabled) TrendSource.productHunt,
      if (activeFilters.devToEnabled) TrendSource.devTo,
    };

    return Scaffold(
      floatingActionButton: AnimatedSlide(
        offset: _showFab ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _showFab ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            onPressed: _scrollToTop,
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _accent,
        onRefresh: () async {
          ref.read(feedDisplayCountProvider.notifier).state = feedPageInitial;
          ref.invalidate(feedProvider);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
              scrolledUnderElevation: 3,
              title: const Text('Trending'),
              actions: [
                // ── Break out of bubble toggle ────────────────────────────
                Tooltip(
                  message: _globalMode
                      ? 'Showing all trends — tap for personalized'
                      : 'Personalized — tap to break out of bubble',
                  child: GestureDetector(
                    onTap: () => setState(() => _globalMode = !_globalMode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _globalMode
                            ? const Color(0xFF7B61FF).withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _globalMode
                              ? const Color(0xFF7B61FF).withValues(alpha: 0.6)
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _globalMode
                                ? Icons.public_rounded
                                : Icons.person_rounded,
                            size: 13,
                            color: _globalMode
                                ? const Color(0xFF7B61FF)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _globalMode ? 'Global' : 'For You',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _globalMode
                                      ? const Color(0xFF7B61FF)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // ── Region toggle ────────────────────────────────────────
                _RegionToggle(
                  region: activeFilters.region,
                  onChanged: (r) {
                    ref.read(filterProvider.notifier).setRegion(r);
                    ref.invalidate(feedProvider);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filters',
                  onPressed: () => showFilterSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded),
                  tooltip: 'Profile',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(104),
                child: Column(
                  children: [
                    // ── Category bar ─────────────────────────────────────
                    _CategoryBar(
                      selected: activeFilters.category,
                      onSelected: (cat) {
                        ref.read(filterProvider.notifier).setCategory(cat);
                        // Reset topic preset when category changes
                        ref.read(topicPresetProvider.notifier).state = null;
                        ref.invalidate(feedProvider);
                      },
                    ),
                    // ── Source filter bar ─────────────────────────────────
                    _SourceFilterBar(
                      selected: _sourceFilter,
                      enabledSources: enabledSources,
                      onSelected: (s) => setState(() => _sourceFilter = s),
                    ),
                  ],
                ),
              ),
            ),

            // ── Signal Radar hero cards ───────────────────────────────────
            if (radarClusters.isNotEmpty)
              SliverToBoxAdapter(
                child: _RadarSection(
                  clusters: radarClusters,
                  activeClusterId: _activeRadarClusterId,
                  onClusterTap: (id) => setState(() {
                    _activeRadarClusterId =
                        _activeRadarClusterId == id ? null : id;
                    _activeClusterTopic = null; // clear alert filter
                  }),
                ),
              ),

            // ── Bubble break banner ───────────────────────────────────────
            if (_globalMode)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            const Color(0xFF7B61FF).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded,
                          size: 16, color: Color(0xFF7B61FF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing all trends — personalization off',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF7B61FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _globalMode = false),
                        child: Icon(Icons.close_rounded,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Cross-platform cluster alert ──────────────────────────────
            if (alert != null && alert.topic != _dismissedAlertTopic)
              SliverToBoxAdapter(
                child: _ClusterAlertBanner(
                  alert: alert,
                  isActive: _activeClusterTopic == alert.topic,
                  onTap: () => setState(() {
                    _activeClusterTopic = _activeClusterTopic == alert.topic
                        ? null
                        : alert.topic;
                  }),
                  onDismiss: () => setState(() {
                    _dismissedAlertTopic = alert.topic;
                    _activeClusterTopic = null;
                  }),
                ),
              ),

            // ── Feed ─────────────────────────────────────────────────────
            feedAsync.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => _TrendShimmer(
                      isDark: Theme.of(context).brightness == Brightness.dark),
                  childCount: 6,
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text('Failed to load trends',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: _accent),
                        onPressed: () => ref.invalidate(feedProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                var filtered = _sourceFilter == null
                    ? items
                    : items.where((i) => i.source == _sourceFilter).toList();
                // Filter out not-interested items
                if (notInterested.isNotEmpty) {
                  filtered = filtered
                      .where((i) => !notInterested.contains(i.id))
                      .toList();
                }
                // Radar cluster filter takes priority over topic filter
                if (_activeRadarClusterId != null) {
                  filtered = filtered
                      .where((i) => i.clusterId == _activeRadarClusterId)
                      .toList();
                } else if (_activeClusterTopic != null) {
                  final kw = _activeClusterTopic!.toLowerCase();
                  filtered = filtered.where((i) =>
                      i.title.toLowerCase().contains(kw) ||
                      i.tags.any((t) => t.toLowerCase() == kw) ||
                      (i.description?.toLowerCase().contains(kw) ?? false))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 56,
                              color: scheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No trending content',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayCount = ref.watch(feedDisplayCountProvider);
                final displayed = filtered.take(displayCount).toList();
                final hasMore = filtered.length > displayCount;

                return SliverMainAxisGroup(slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => TrendCard(item: displayed[i]),
                      childCount: displayed.length,
                    ),
                  ),
                  if (hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.expand_more, size: 16),
                          label: Text(
                            'Load ${(filtered.length - displayCount).clamp(0, feedPageStep)} more'
                            ' (${filtered.length - displayCount} remaining)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => ref
                              .read(feedDisplayCountProvider.notifier)
                              .state += feedPageStep,
                        ),
                      ),
                    ),
                ]);
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Region toggle ─────────────────────────────────────────────────────────────

class _RegionToggle extends StatelessWidget {
  final FeedRegion region;
  final ValueChanged<FeedRegion> onChanged;

  const _RegionToggle({required this.region, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isIndia = region == FeedRegion.india;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            label: '🌐 Global',
            selected: !isIndia,
            selectedColor: const Color(0xFF7B61FF),
            onTap: () => onChanged(FeedRegion.global),
          ),
          _Option(
            label: '🇮🇳 India',
            selected: isIndia,
            selectedColor: const Color(0xFF138808),
            onTap: () => onChanged(FeedRegion.india),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _Option({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: selectedColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? selectedColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// ── Category bar ──────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final FeedCategory selected;
  final ValueChanged<FeedCategory> onSelected;

  const _CategoryBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: FeedCategory.values.map((cat) {
          final meta = _categoryMeta[cat]!;
          final label = meta.$1;
          final icon = meta.$2;
          final color = meta.$3;
          final isSelected = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(icon, size: 15, color: isSelected ? color : null),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelected(cat),
              selectedColor: color.withValues(alpha: 0.15),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cross-platform cluster alert banner ──────────────────────────────────────

class _ClusterAlertBanner extends StatelessWidget {
  final ClusterAlert alert;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ClusterAlertBanner({
    required this.alert,
    required this.isActive,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const amber = Color(0xFFF59E0B);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? amber.withValues(alpha: 0.2)
              : amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive
                  ? amber.withValues(alpha: 0.8)
                  : amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"${alert.topic[0].toUpperCase()}${alert.topic.substring(1)}" trending across '
                '${alert.sourceCount} platform${alert.sourceCount == 1 ? '' : 's'} '
                '· ${alert.itemCount} stories'
                '${isActive ? ' — tap to clear' : ' — tap to view'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source filter chips ───────────────────────────────────────────────────────

class _SourceFilterBar extends StatelessWidget {
  final TrendSource? selected;
  final Set<TrendSource> enabledSources;
  final ValueChanged<TrendSource?> onSelected;

  const _SourceFilterBar({
    required this.selected,
    required this.enabledSources,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final allChips = [
      (null, Icons.all_inclusive_outlined, 'All'),
      (TrendSource.youtube, Icons.play_circle_outline, 'YouTube'),
      (TrendSource.reddit, Icons.reddit, 'Reddit'),
      (TrendSource.news, Icons.newspaper_outlined, 'News'),
      (TrendSource.github, Icons.code_rounded, 'GitHub'),
      (TrendSource.hackerNews, Icons.terminal_rounded, 'HN'),
      (TrendSource.productHunt, Icons.rocket_launch_rounded, 'PH'),
      (TrendSource.devTo, Icons.article_outlined, 'Dev.to'),
    ];
    final chips = allChips
        .where((c) => c.$1 == null || enabledSources.contains(c.$1))
        .toList();

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: chips.map((c) {
          final isSelected = selected == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(c.$2, size: 15),
              label: Text(c.$3),
              selected: isSelected,
              onSelected: (_) => onSelected(c.$1),
              selectedColor: _accent.withValues(alpha: 0.15),
              checkmarkColor: _accent,
              labelStyle: TextStyle(
                color: isSelected ? _accent : null,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? _accent.withValues(alpha: 0.5)
                    : Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Signal Radar ──────────────────────────────────────────────────────────────

class _RadarSection extends StatelessWidget {
  final List<RadarCluster> clusters;
  final String? activeClusterId;
  final ValueChanged<String> onClusterTap;

  const _RadarSection({
    required this.clusters,
    required this.activeClusterId,
    required this.onClusterTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.radar, size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(
                'Signal Radar',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _accent,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${clusters.length} cluster${clusters.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (activeClusterId != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => onClusterTap(activeClusterId!),
                  child: Text(
                    'Clear filter',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: clusters.length,
            itemBuilder: (_, i) => _RadarCard(
              cluster: clusters[i],
              isActive: clusters[i].id == activeClusterId,
              onTap: () => onClusterTap(clusters[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarCard extends StatelessWidget {
  final RadarCluster cluster;
  final bool isActive;
  final VoidCallback onTap;

  const _RadarCard({
    required this.cluster,
    required this.isActive,
    required this.onTap,
  });

  // Gradient per dominant sentiment
  static const _sentimentGradients = {
    TrendSentiment.positive: [Color(0xFF22C55E), Color(0xFF16A34A)],
    TrendSentiment.critical: [Color(0xFFEF4444), Color(0xFFDC2626)],
    TrendSentiment.controversial: [Color(0xFFF59E0B), Color(0xFFD97706)],
    TrendSentiment.neutral: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  };

  static const _sourceIcons = {
    TrendSource.youtube: Icons.play_circle_outline,
    TrendSource.reddit: Icons.reddit,
    TrendSource.news: Icons.newspaper_outlined,
    TrendSource.github: Icons.code_rounded,
    TrendSource.hackerNews: Icons.terminal_rounded,
    TrendSource.productHunt: Icons.rocket_launch_outlined,
    TrendSource.devTo: Icons.article_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = _sentimentGradients[cluster.dominantSentiment]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isActive
                ? colors
                : [
                    colors[0].withValues(alpha: 0.7),
                    colors[1].withValues(alpha: 0.7),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: isActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic + sentiment
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${cluster.topic}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SentimentBadge(sentiment: cluster.dominantSentiment),
              ],
            ),
            const SizedBox(height: 6),
            // Top story title
            Text(
              cluster.topItem.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Stats row
            Row(
              children: [
                // Source icons
                ...cluster.sources.take(4).map((s) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        _sourceIcons[s] ?? Icons.circle,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )),
                const Spacer(),
                // Item count + momentum
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cluster.itemCount} stories'
                    '${cluster.momentum == 'rising' ? ' 🔥' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _TrendShimmer extends StatelessWidget {
  final bool isDark;
  const _TrendShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 160, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 80, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                      height: 14, width: 200, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                      height: 10, width: 120, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
