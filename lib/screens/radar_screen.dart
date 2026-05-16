import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/trend_item.dart';
import '../providers/feed_provider.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_skeleton.dart';
import '../widgets/sentiment_badge.dart';
import '../widgets/trend_card.dart';
import 'cluster_detail_screen.dart';

// ── Wikipedia topic image (free, no API key) ──────────────────────────────────
// Uses the MediaWiki search API — fuzzy matching, handles disambiguation,
// and is case-insensitive. Returns a 640-px thumbnail or null.
final _wikiImageProvider =
    FutureProvider.family<String?, String>((ref, topic) async {
  try {
    final q = Uri.encodeQueryComponent(topic);
    final url = Uri.parse(
      'https://en.wikipedia.org/w/api.php'
      '?action=query&generator=search&gsrsearch=$q&gsrlimit=1'
      '&prop=pageimages&piprop=thumbnail&pithumbsize=640'
      '&format=json&origin=*',
    );
    final res = await http
        .get(url, headers: {'User-Agent': 'UniTrend/1.0 (topic-image)'})
        .timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final pages = (data['query'] as Map<String, dynamic>?)?['pages']
        as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) return null;

    final page = pages.values.first as Map<String, dynamic>;
    final thumb = page['thumbnail'] as Map<String, dynamic>?;
    return thumb?['source'] as String?;
  } catch (_) {
    return null;
  }
});

// ── Source icons map ──────────────────────────────────────────────────────────
const _sourceIcons = {
  TrendSource.youtube: Icons.play_circle_outline,
  TrendSource.reddit: Icons.chat_bubble_outline,
  TrendSource.news: Icons.newspaper_outlined,
  TrendSource.github: Icons.code,
  TrendSource.hackerNews: Icons.whatshot_outlined,
  TrendSource.productHunt: Icons.rocket_launch_outlined,
  TrendSource.devTo: Icons.developer_mode_outlined,
};

const _sourceColors = {
  TrendSource.youtube: Color(0xFFFF0000),
  TrendSource.reddit: Color(0xFFFF4500),
  TrendSource.news: Color(0xFF1565C0),
  TrendSource.github: Color(0xFF238636),
  TrendSource.hackerNews: Color(0xFFFF6600),
  TrendSource.productHunt: Color(0xFFDA552F),
  TrendSource.devTo: Color(0xFF0A0A0A),
};

const _sentimentGradients = {
  TrendSentiment.positive: [Color(0xFF10B981), Color(0xFF059669)],
  TrendSentiment.critical: [Color(0xFFEF4444), Color(0xFFB91C1C)],
  TrendSentiment.controversial: [Color(0xFFF59E0B), Color(0xFFB45309)],
  TrendSentiment.neutral: [Color(0xFF7B61FF), Color(0xFF4F46E5)],
};

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  String? _activeClusterId;

  @override
  Widget build(BuildContext context) {
    final clusters = ref.watch(radarClustersProvider);
    final feedAsync = ref.watch(feedProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(builder: (context) {
          if (feedAsync.isLoading) {
            return _RadarSkeleton();
          }
          if (clusters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No signal clusters yet',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Pull to refresh',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          final activeCluster = _activeClusterId != null
              ? clusters.firstWhere(
                  (c) => c.id == _activeClusterId,
                  orElse: () => clusters.first,
                )
              : clusters.first;

          return CustomScrollView(
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
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF0A0A0F).withValues(alpha: 0.6)
                          : theme.colorScheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.accentGradient.createShader(b),
                      child: const Icon(Icons.radar, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.accentGradient.createShader(b),
                      child: Text(
                        'Signal Radar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: const [],
              ),

              // ── Hero cards ────────────────────────────────────────────
              SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: clusters.length,
                      itemBuilder: (context, index) {
                        final cluster = clusters[index];
                        final isActive =
                            (_activeClusterId ?? clusters.first.id) ==
                                cluster.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _activeClusterId = cluster.id),
                          child: _HeroCard(
                            cluster: cluster,
                            isActive: isActive,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // ── Active cluster label + Deep Dive ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '#${activeCluster.topic}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activeCluster.items.length} stories',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      _SourceIconRow(sources: activeCluster.sources),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 13),
                        label: const Text('Deep Dive'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClusterDetailScreen(
                                cluster: activeCluster),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // ── Stories in active cluster ────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      TrendCard(item: activeCluster.items[index]),
                  childCount: activeCluster.items.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final RadarCluster cluster;
  final bool isActive;

  const _HeroCard({required this.cluster, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradColors = _sentimentGradients[cluster.dominantSentiment] ??
        _sentimentGradients[TrendSentiment.neutral]!;
    final thumb = cluster.topItem.thumbnailUrl;
    // Fall back to Wikipedia image when the cluster has no thumbnail
    final wikiAsync = thumb == null
        ? ref.watch(_wikiImageProvider(cluster.topic))
        : const AsyncData<String?>(null);
    final effectiveThumb = thumb ?? wikiAsync.valueOrNull;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? gradColors.first.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: gradColors.first.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: thumbnail / wiki image / rich fallback ────────
            if (effectiveThumb != null)
              CachedNetworkImage(
                imageUrl: effectiveThumb,
                memCacheWidth: 500,
                memCacheHeight: 400,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    _NoThumbBg(colors: gradColors, topic: cluster.topic),
              )
            else if (wikiAsync.isLoading)
              // Shimmer while the wiki request is in flight
              _ShimmerBg(colors: gradColors)
            else
              _NoThumbBg(colors: gradColors, topic: cluster.topic),

            // ── Dark gradient overlay ──────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source icons + sentiment badge
                  Row(
                    children: [
                      _SourceIconRow(sources: cluster.sources, small: true),
                      const Spacer(),
                      if (cluster.dominantSentiment != TrendSentiment.neutral)
                        SentimentBadge(
                            sentiment: cluster.dominantSentiment,
                            compact: true),
                    ],
                  ),
                  const Spacer(),

                  // Topic label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradColors),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${cluster.topic}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Top item title
                  Text(
                    cluster.topItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Velocity + item count
                  Row(
                    children: [
                      Text(
                        '${cluster.items.length} stories',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (cluster.momentum == 'rising') ...[
                        const SizedBox(width: 4),
                        const Text('🔥',
                            style: TextStyle(fontSize: 11)),
                      ],
                    ],
                  ),

                  // Open top story button
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => LinkOpener.open(
                        context, cluster.topItem.url),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        Text(
                          'Open top story',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source icon row ───────────────────────────────────────────────────────────

class _SourceIconRow extends StatelessWidget {
  final Set<TrendSource> sources;
  final bool small;

  const _SourceIconRow({required this.sources, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 14.0 : 16.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sources.take(4).map((src) {
        final color = _sourceColors[src] ?? Colors.grey;
        final icon = _sourceIcons[src] ?? Icons.public;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(icon, size: size, color: color),
        );
      }).toList(),
    );
  }
}

// ── Rich no-thumbnail background ─────────────────────────────────────────────
// Used when a cluster has no cover image. Shows a multi-stop gradient,
// a radial glow in the top-right corner, and a giant watermark letter.

class _NoThumbBg extends StatelessWidget {
  final List<Color> colors;
  final String topic;

  const _NoThumbBg({required this.colors, required this.topic});

  @override
  Widget build(BuildContext context) {
    final letter = topic.isNotEmpty ? topic[0].toUpperCase() : '#';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient — richer, diagonal
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first,
                Color.lerp(colors.first, colors.last, 0.5)!
                    .withValues(alpha: 0.9),
                colors.last.withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Radial glow in top-right corner
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Giant watermark letter
        Positioned(
          bottom: -8,
          right: -4,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.12),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer bg while wiki image loads ────────────────────────────────────────

class _ShimmerBg extends StatefulWidget {
  final List<Color> colors;
  const _ShimmerBg({required this.colors});

  @override
  State<_ShimmerBg> createState() => _ShimmerBgState();
}

class _ShimmerBgState extends State<_ShimmerBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
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
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: [
              widget.colors.first.withValues(alpha: 0.6),
              widget.colors.first.withValues(alpha: 0.85),
              widget.colors.last.withValues(alpha: 0.9),
              widget.colors.first.withValues(alpha: 0.85),
              widget.colors.first.withValues(alpha: 0.6),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}


// ── Radar skeleton ────────────────────────────────────────────────────────────

class _RadarSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 72, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal card row skeletons
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, _) => Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: GradientSkeleton(
                          width: 200, height: 220, borderRadius: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const GradientSkeleton(height: 14, width: 140),
                const SizedBox(height: 12),
                ...List.generate(
                    4, (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: GradientSkeletonPost(),
                        )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
