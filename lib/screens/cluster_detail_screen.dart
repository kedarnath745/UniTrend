import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trend_item.dart';
import '../providers/feed_provider.dart';
import '../providers/groq_provider.dart';
import '../services/groq_service.dart';
import '../services/score_history_service.dart';
import '../widgets/gradient_skeleton.dart';
import '../widgets/sentiment_badge.dart';
import '../widgets/trend_card.dart';

// ── Source colour map (mirrors radar_screen.dart) ─────────────────────────────
const _sourceColors = {
  TrendSource.youtube:     Color(0xFFFF0000),
  TrendSource.reddit:      Color(0xFFFF4500),
  TrendSource.news:        Color(0xFF1565C0),
  TrendSource.github:      Color(0xFF238636),
  TrendSource.hackerNews:  Color(0xFFFF6600),
  TrendSource.productHunt: Color(0xFFDA552F),
  TrendSource.devTo:       Color(0xFF0A0A0A),
};

const _sourceIcons = {
  TrendSource.youtube:     Icons.play_circle_outline,
  TrendSource.reddit:      Icons.chat_bubble_outline,
  TrendSource.news:        Icons.newspaper_outlined,
  TrendSource.github:      Icons.code,
  TrendSource.hackerNews:  Icons.whatshot_outlined,
  TrendSource.productHunt: Icons.rocket_launch_outlined,
  TrendSource.devTo:       Icons.developer_mode_outlined,
};

const _sentimentGradients = {
  TrendSentiment.positive:     [Color(0xFF10B981), Color(0xFF059669)],
  TrendSentiment.critical:     [Color(0xFFEF4444), Color(0xFFB91C1C)],
  TrendSentiment.controversial:[Color(0xFFF59E0B), Color(0xFFB45309)],
  TrendSentiment.neutral:      [Color(0xFF7B61FF), Color(0xFF4F46E5)],
};

const _accent = Color(0xFFFF5722);

// ── Score history providers ───────────────────────────────────────────────────

final _scoreHistoryServiceProvider = Provider((_) => ScoreHistoryService());

final _dailyHistoryProvider =
    FutureProvider.family<List<DailyScore>, String>((ref, clusterId) async {
  final svc = ref.watch(_scoreHistoryServiceProvider);
  return svc.getDailyAggregated(clusterId, days: 7);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClusterDetailScreen extends ConsumerStatefulWidget {
  final RadarCluster cluster;

  const ClusterDetailScreen({super.key, required this.cluster});

  @override
  ConsumerState<ClusterDetailScreen> createState() =>
      _ClusterDetailScreenState();
}

class _ClusterDetailScreenState extends ConsumerState<ClusterDetailScreen> {
  bool _comparisonExpanded = false;

  RadarCluster get c => widget.cluster;

  void _openChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSheet(cluster: c),
    );
  }

  @override
  void initState() {
    super.initState();
    // Eagerly record today's score so every visit contributes a data point.
    // The 2-hour dedup in ScoreHistoryService prevents duplicate entries.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc = ref.read(_scoreHistoryServiceProvider);
      await svc.snapshot([(
        id: c.id,
        topic: c.topic,
        score: c.items.first.normalizedScore,
      )]);
      // Refresh so the chart picks up the new point immediately
      ref.invalidate(_dailyHistoryProvider(c.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradColors =
        _sentimentGradients[c.dominantSentiment] ?? _sentimentGradients[TrendSentiment.neutral]!;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChatSheet(context),
        tooltip: 'Ask the Researcher',
        child: const Icon(Icons.chat_outlined),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Blurred hero app bar ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'Share cluster',
                onPressed: () {
                  final deepLink = 'unitrend://cluster/${c.id}';
                  final text =
                      '🔥 #${c.topic} is trending across ${c.sources.length} sources\n\n'
                      'Open in UniTrend: $deepLink';
                  HapticFeedback.lightImpact();
                  Share.share(text, subject: '#${c.topic} is trending on UniTrend');
                },
              ),
            ],
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.blurBackground],
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradColors.first.withValues(alpha: 0.7),
                          gradColors.last.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '#${c.topic}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (c.dominantSentiment != TrendSentiment.neutral)
                                SentimentBadge(
                                    sentiment: c.dominantSentiment,
                                    compact: false),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(child: _SourceChips(sources: c.sources)),
                              const SizedBox(width: 8),
                              Text(
                                '${c.itemCount} stories',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              if (c.momentum == 'rising') ...[
                                const SizedBox(width: 4),
                                const Text('🔥',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Trend history chart ───────────────────────────────────
                _TrendHistoryCard(cluster: c, gradColors: gradColors),

                // ── Source breakdown ──────────────────────────────────────
                _SourceBreakdownSection(cluster: c),

                // ── AI Source Comparison ──────────────────────────────────
                _AiComparisonSection(
                  cluster: c,
                  expanded: _comparisonExpanded,
                  onToggle: () =>
                      setState(() => _comparisonExpanded = !_comparisonExpanded),
                ),

                // ── Timeline ─────────────────────────────────────────────
                _TimelineSection(cluster: c),

                _SectionHeader('All Stories (${c.itemCount})'),
              ],
            ),
          ),

          // ── Full stories list ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => TrendCard(item: c.items[i]),
              childCount: c.items.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Trend History Card ────────────────────────────────────────────────────────

class _TrendHistoryCard extends ConsumerWidget {
  final RadarCluster cluster;
  final List<Color> gradColors;

  const _TrendHistoryCard({required this.cluster, required this.gradColors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_dailyHistoryProvider(cluster.id));
    final lineColor = gradColors.first;

    return _Card(
      child: historyAsync.when(
        loading: () => const _ChartLoading(),
        error: (e, _) => const _ChartLoading(),
        data: (dailyScores) {
          // ── Build chart data ─────────────────────────────────────────────
          // Blend: real snapshots where available + synthetic item activity
          // for unmeasured days.
          final chartDays = _buildChartDays(dailyScores, cluster.items);

          // Stats: current score, 7-day delta, measurement count
          final currentScore = cluster.items.first.normalizedScore;
          final measuredDays =
              dailyScores.where((d) => d.isMeasured).toList();
          final delta = measuredDays.length >= 2
              ? measuredDays.last.score - measuredDays.first.score
              : null;
          final hasTrend = measuredDays.length >= 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────────
              Row(
                children: [
                  _SectionTitle(
                    hasTrend ? 'Score Trend (7d)' : 'Story Activity (7d)',
                    Icons.show_chart_rounded,
                  ),
                  const Spacer(),
                  if (!hasTrend)
                    Tooltip(
                      message: 'Open this topic daily to build a score history',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Text(
                            'Estimated',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Stats row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    _StatCell(
                      label: 'Score',
                      value: currentScore.toStringAsFixed(1),
                      color: lineColor,
                    ),
                    _StatDivider(),
                    _StatCell(
                      label: '7d Change',
                      value: delta == null
                          ? '—'
                          : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                      color: delta == null
                          ? null
                          : (delta >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444)),
                      prefix: delta == null
                          ? null
                          : (delta >= 0 ? '↑ ' : '↓ '),
                    ),
                    _StatDivider(),
                    _StatCell(
                      label: 'Momentum',
                      value: _momentumLabel(cluster.momentum),
                      color: _momentumColor(cluster.momentum),
                    ),
                  ],
                ),
              ),

              // ── Chart ───────────────────────────────────────────────────
              _TrendLineChart(
                days: chartDays,
                lineColor: lineColor,
                hasMeasuredTrend: hasTrend,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Merges DailyScore (real measurements) with synthetic item activity.
  /// For unmeasured days, estimates the score from items published that day.
  List<_ChartDay> _buildChartDays(
      List<DailyScore> dailyScores, List<TrendItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Sum of normalised scores for items published each day
    final itemActivity = <DateTime, double>{};
    for (final item in items) {
      final day = DateTime(item.publishedAt.year, item.publishedAt.month,
          item.publishedAt.day);
      final daysAgo = today.difference(day).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        itemActivity[day] = (itemActivity[day] ?? 0) + item.normalizedScore;
      }
    }

    return dailyScores.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      if (d.isMeasured) {
        return _ChartDay(x: i.toDouble(), y: d.score, measured: true, day: d.day);
      }
      // Synthetic: cap at 100 so it fits the same axis as real scores
      final synthetic = (itemActivity[d.day] ?? 0).clamp(0.0, 100.0);
      return _ChartDay(x: i.toDouble(), y: synthetic, measured: false, day: d.day);
    }).toList();
  }

  String _momentumLabel(String momentum) {
    switch (momentum) {
      case 'rising':  return '↑ Rising';
      case 'cooling': return '↓ Cooling';
      default:        return '→ Stable';
    }
  }

  Color _momentumColor(String momentum) {
    switch (momentum) {
      case 'rising':  return const Color(0xFF10B981);
      case 'cooling': return const Color(0xFFEF4444);
      default:        return const Color(0xFFF59E0B);
    }
  }
}

// ── Chart day data class ──────────────────────────────────────────────────────

class _ChartDay {
  final double x;
  final double y;
  final bool measured;
  final DateTime day;
  const _ChartDay({required this.x, required this.y, required this.measured, required this.day});
}

// ── Trend Line Chart ──────────────────────────────────────────────────────────

class _TrendLineChart extends StatelessWidget {
  final List<_ChartDay> days;
  final Color lineColor;
  final bool hasMeasuredTrend;

  const _TrendLineChart({
    required this.days,
    required this.lineColor,
    required this.hasMeasuredTrend,
  });

  @override
  Widget build(BuildContext context) {
    // Build two series: solid for measured, dashed for synthetic
    final measuredSpots = days
        .where((d) => d.measured)
        .map((d) => FlSpot(d.x, d.y))
        .toList();
    final syntheticSpots = days
        .where((d) => !d.measured && d.y > 0)
        .map((d) => FlSpot(d.x, d.y))
        .toList();

    // If no synthetic activity and not enough measured: show all days as 0
    final allSpots = days.map((d) => FlSpot(d.x, d.y)).toList();

    final nonZero = days.where((d) => d.y > 0).toList();
    final maxY = nonZero.isEmpty
        ? 20.0
        : (nonZero.map((d) => d.y).reduce((a, b) => a > b ? a : b) + 8)
            .clamp(10.0, 105.0);
    final minY = nonZero.isEmpty
        ? 0.0
        : (nonZero.map((d) => d.y).reduce((a, b) => a < b ? a : b) - 8)
            .clamp(0.0, maxY - 5);

    final dayFmt = DateFormat('E'); // Mon, Tue…

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 6,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    dayFmt.format(days[idx].day),
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            // Synthetic / estimated activity (dashed, lower opacity)
            if (syntheticSpots.isNotEmpty && !hasMeasuredTrend)
              LineChartBarData(
                spots: allSpots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: lineColor.withValues(alpha: 0.45),
                barWidth: 2,
                dashArray: [5, 4],
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: days[idx].measured ? 4 : 2.5,
                    color: days[idx].measured
                        ? lineColor
                        : lineColor.withValues(alpha: 0.45),
                    strokeColor: Colors.white,
                    strokeWidth: 1,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      lineColor.withValues(alpha: 0.12),
                      lineColor.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            // Measured score trend (solid, full opacity)
            if (measuredSpots.length >= 2)
              LineChartBarData(
                spots: measuredSpots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeColor: Colors.white,
                    strokeWidth: 1.5,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      lineColor.withValues(alpha: 0.25),
                      lineColor.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            // Single measured point — just a dot, no line
            if (measuredSpots.length == 1)
              LineChartBarData(
                spots: measuredSpots,
                isCurved: false,
                color: Colors.transparent,
                barWidth: 0,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: 5,
                    color: lineColor,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.inverseSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  final idx = s.x.toInt().clamp(0, days.length - 1);
                  final d = days[idx];
                  final label = d.measured
                      ? s.y.toStringAsFixed(1)
                      : '~${s.y.toStringAsFixed(0)} activity';
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(d.day)}\n$label',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat cells ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final String? prefix;

  const _StatCell({
    required this.label,
    required this.value,
    this.color,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${prefix ?? ''}$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientSkeleton(height: 120),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: GradientSkeleton(height: 32)),
              SizedBox(width: 12),
              Expanded(child: GradientSkeleton(height: 32)),
              SizedBox(width: 12),
              Expanded(child: GradientSkeleton(height: 32)),
            ]),
          ],
        ),
      );
}

// ── Source Breakdown ──────────────────────────────────────────────────────────

class _SourceBreakdownSection extends StatelessWidget {
  final RadarCluster cluster;
  const _SourceBreakdownSection({required this.cluster});

  @override
  Widget build(BuildContext context) {
    // Group items by source, count them
    final bySource = <TrendSource, List<TrendItem>>{};
    for (final item in cluster.items) {
      bySource.putIfAbsent(item.source, () => []).add(item);
    }

    final sorted = bySource.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Source Breakdown', Icons.hub_outlined),
          const SizedBox(height: 12),
          ...sorted.map((entry) => _SourceRow(
                source: entry.key,
                items: entry.value,
                total: cluster.itemCount,
              )),
        ],
      ),
    );
  }
}

class _SourceRow extends StatefulWidget {
  final TrendSource source;
  final List<TrendItem> items;
  final int total;

  const _SourceRow(
      {required this.source, required this.items, required this.total});

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColors[widget.source] ?? Colors.grey;
    final icon = _sourceIcons[widget.source] ?? Icons.public;
    final pct = widget.items.length / widget.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.source.name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.items.length} stories',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: color.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation(
                                  color.withValues(alpha: 0.7)),
                              minHeight: 8,
                            ),
                          ),
                          // Percentage label inside the bar
                          Positioned(
                            left: 6,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                '${(pct * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          ...widget.items.take(3).map((item) => Padding(
                padding:
                    const EdgeInsets.only(left: 24, bottom: 4),
                child: Text(
                  '• ${item.title}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ── AI Comparison ─────────────────────────────────────────────────────────────

class _AiComparisonSection extends ConsumerWidget {
  final RadarCluster cluster;
  final bool expanded;
  final VoidCallback onToggle;

  const _AiComparisonSection({
    required this.cluster,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisons = ref.watch(sourceComparisonProvider);
    final compAsync = comparisons[cluster.id];
    final theme = Theme.of(context);
    final multiSource = cluster.sources.length >= 2;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: multiSource
                ? () {
                    onToggle();
                    if (!expanded && compAsync == null) {
                      ref.read(sourceComparisonProvider.notifier).fetch(
                            cluster.id,
                            cluster.items,
                            cluster.topic,
                          );
                    }
                  }
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF4F46E5)],
                  ).createShader(b),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI: How Each Source Frames This',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (multiSource)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else
                  Text(
                    'Single source',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (!multiSource) ...[
            const SizedBox(height: 8),
            Text(
              'All ${cluster.itemCount} stories come from ${cluster.sources.first.name}. '
              'Cross-source comparison is available once this topic is picked up by other platforms.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (expanded) ...[
            const SizedBox(height: 12),
            _buildContent(context, ref, compAsync),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, AsyncValue<String>? compAsync) {
    if (compAsync == null || compAsync is AsyncLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (compAsync is AsyncError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Could not load comparison.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(sourceComparisonProvider.notifier).retry(cluster.id);
              ref.read(sourceComparisonProvider.notifier).fetch(
                    cluster.id,
                    cluster.items,
                    cluster.topic,
                  );
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final text = (compAsync as AsyncData<String>).value;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── Timeline Section ──────────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  final RadarCluster cluster;
  const _TimelineSection({required this.cluster});

  @override
  Widget build(BuildContext context) {
    // Sort items oldest → newest to show who broke the story first
    final sorted = [...cluster.items]
      ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

    final earliest = sorted.first.publishedAt;
    final latest = sorted.last.publishedAt;
    // Only show relative offsets when the full span is ≤ 7 days —
    // beyond that, individual offsets convey no "who broke it first" signal.
    final spansMultiDays =
        latest.difference(earliest).inDays > 7;
    final fmt = DateFormat('MMM d, HH:mm');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Story Timeline', Icons.timeline_rounded),
          const SizedBox(height: 12),
          ...sorted.take(8).map((item) {
            final color = _sourceColors[item.source] ?? Colors.grey;
            final icon = _sourceIcons[item.source] ?? Icons.public;
            final minsAfter =
                item.publishedAt.difference(earliest).inMinutes;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline dot + line
                  Column(
                    children: [
                      Icon(icon, size: 14, color: color),
                      Container(
                        width: 1,
                        height: 24,
                        color: color.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fmt.format(item.publishedAt.toLocal()),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (minsAfter == 0)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text('🏁',
                                    style: TextStyle(fontSize: 10)),
                              )
                            else if (!spansMultiDays)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '+${_humanizeMins(minsAfter)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 11, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _humanizeMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    if (h < 24) {
      final m = mins % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    final d = h ~/ 24;
    final remH = h % 24;
    return remH == 0 ? '${d}d' : '${d}d ${remH}h';
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionTitle(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: _accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}

class _SourceChips extends StatelessWidget {
  final Set<TrendSource> sources;
  const _SourceChips({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: sources.map((s) {
        final color = _sourceColors[s] ?? Colors.grey;
        final icon = _sourceIcons[s] ?? Icons.public;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(
                s.name,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Chat Sheet ─────────────────────────────────────────────────────────────────

class _ChatMsg {
  final String role; // 'user' | 'assistant'
  final String content;
  const _ChatMsg({required this.role, required this.content});
}

class _ChatSheet extends StatefulWidget {
  final RadarCluster cluster;
  const _ChatSheet({required this.cluster});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMsg>[];
  bool _loading = false;
  final _groq = GroqService();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_ChatMsg(role: 'user', content: q));
      _loading = true;
    });
    _scrollToBottom();

    // Build history for context (exclude current user message, already appended)
    final history = _messages
        .take(_messages.length - 1)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      final reply = await _groq.chatWithCluster(
        widget.cluster.items,
        q,
        history: history,
      );
      setState(() {
        _loading = false;
        _messages.add(_ChatMsg(role: 'assistant', content: reply));
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _messages.add(const _ChatMsg(
          role: 'assistant',
          content: 'Sorry, I couldn\'t answer that. Check your connection and try again.',
        ));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF12121A) : theme.colorScheme.surface;
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: sheetBg,
          child: Column(
            children: [
              // ── Handle + header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFF4F46E5)],
                          ).createShader(b),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ask the Researcher',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Powered by Groq · Context: #${widget.cluster.topic}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Message list ─────────────────────────────────────────────
              Expanded(
                child: _messages.isEmpty
                    ? _ChatEmptyState(topic: widget.cluster.topic)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length + (_loading ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_loading && i == _messages.length) {
                            return const _TypingIndicator();
                          }
                          final msg = _messages[i];
                          return _ChatBubble(msg: msg);
                        },
                      ),
              ),

              // ── Input bar ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 8, 12, mq.viewInsets.bottom + 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          hintText: 'Ask anything about #${widget.cluster.topic}…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        minimumSize: Size.zero,
                      ),
                      onPressed: _loading ? null : () => _send(_ctrl.text),
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : (isDark
                  ? const Color(0xFF1E1E2E)
                  : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isUser
                ? Colors.white
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E2E)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i / 3;
                final opacity = ((_ctrl.value - delay) % 1.0).abs();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3 + opacity * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  final String topic;
  const _ChatEmptyState({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = [
      'Why is #$topic trending right now?',
      'What\'s the most surprising angle on this?',
      'Who does this impact the most?',
      'What happens next?',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF4F46E5)],
              ).createShader(b),
              child: const Icon(Icons.psychology_outlined,
                  color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ask me anything about #$topic',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Try asking:',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...suggestions.map((s) => _SuggestionChip(text: s)),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}
