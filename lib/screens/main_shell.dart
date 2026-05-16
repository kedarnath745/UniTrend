import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/feedback_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/scroll_to_top_provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/notification_service.dart';
import '../services/score_history_service.dart';
import '../widgets/floating_bottom_nav.dart';
import 'bookmarks_screen.dart';
import 'cluster_detail_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'radar_screen.dart';
import 'search_screen.dart';
import 'trending_screen.dart';

// Global nav index provider so any screen can switch tabs
final navIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  final _scoreHistorySvc = ScoreHistoryService();

  static const _pauseSnapshotKey = 'unitrend_pause_snapshot_v1';
  static const _awayThresholdHours = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
      _listenForDeepLinks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle == AppLifecycleState.paused) {
      _savePausedSnapshot();
    } else if (lifecycle == AppLifecycleState.resumed) {
      _checkWhatChanged();
    }
  }

  Future<void> _savePausedSnapshot() async {
    final clusters = ref.read(radarClustersProvider);
    if (clusters.isEmpty) return;
    final topics = clusters.take(10).map((c) => c.topic).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pauseSnapshotKey,
      jsonEncode({
        'topics': topics,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _checkWhatChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pauseSnapshotKey);
    if (raw == null) return;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final ts = data['ts'] as int;
    final oldTopics =
        (data['topics'] as List).cast<String>().toSet();

    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (elapsed.inHours < _awayThresholdHours) return;

    // Give the feed a moment to refresh before comparing
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final clusters = ref.read(radarClustersProvider);
    if (clusters.isEmpty) return;
    final newTopics = clusters.take(10).map((c) => c.topic).toSet();

    final appeared = newTopics.difference(oldTopics).toList();
    final disappeared = oldTopics.difference(newTopics).toList();

    if (appeared.isEmpty && disappeared.isEmpty) return;

    final parts = <String>[];
    if (appeared.isNotEmpty) {
      parts.add('New: ${appeared.take(3).map((t) => '#$t').join(', ')}');
    }
    if (disappeared.isNotEmpty) {
      parts.add('Gone: ${disappeared.take(2).map((t) => '#$t').join(', ')}');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: const Icon(Icons.update_rounded, color: Color(0xFFFF6B35)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        content: Text(
          'While you were away — ${parts.join(' · ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _listenForDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'unitrend' || uri.host != 'cluster') return;
    final clusterId = uri.pathSegments.firstOrNull;
    if (clusterId == null) return;

    ref.read(navIndexProvider.notifier).state = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clusters = ref.read(radarClustersProvider);
      final cluster = clusters.where((c) => c.id == clusterId).firstOrNull;
      if (cluster != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClusterDetailScreen(cluster: cluster),
          ),
        );
      }
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    if (!done && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(feedbackLoaderProvider);
    final index = ref.watch(navIndexProvider);

    // ── Score snapshots — save every time clusters refresh ───────────────────
    ref.listen<List<RadarCluster>>(radarClustersProvider, (_, clusters) {
      if (clusters.isEmpty) return;
      final data = clusters
          .map((c) => (
                id: c.id,
                topic: c.topic,
                score: c.items.first.normalizedScore,
              ))
          .toList();
      _scoreHistorySvc.snapshot(data);
    });

    // ── Watchlist alerts — fire local notification when score > 80 ───────────
    ref.listen<AsyncValue<Map<String, List<dynamic>>>>(
      watchlistFeedProvider,
      (_, next) {
        next.whenData((map) {
          for (final entry in map.entries) {
            final keyword = entry.key;
            for (final item in entry.value) {
              if (item.normalizedScore > 80) {
                NotificationService.maybeNotify(
                  itemId: item.id,
                  keyword: keyword,
                  title: item.title,
                );
              }
            }
          }
        });
      },
    );

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          RadarScreen(),
          HomeScreen(),
          SearchScreen(),
          TrendingScreen(),
          BookmarksScreen(),
        ],
      ),
      bottomNavigationBar: FloatingBottomNav(
        selectedIndex: index,
        onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
        onDoubleTap: (i) {
          switch (i) {
            case 0: ref.read(radarScrollToTopProvider.notifier).state++;
            case 1: ref.read(homeScrollToTopProvider.notifier).state++;
            case 3: ref.read(trendingScrollToTopProvider.notifier).state++;
            case 4: ref.read(bookmarksScrollToTopProvider.notifier).state++;
          }
        },
      ),
    );
  }
}
