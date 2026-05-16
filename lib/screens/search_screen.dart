import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trend_item.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/search_provider.dart';
import '../providers/user_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/saved_dashboards_provider.dart';
import '../services/link_opener.dart';
import '../widgets/trend_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/floating_orbs_background.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/gradient_skeleton.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

const _accent = Color(0xFFFF5722);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _searchFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = trimmed;
    _saveToHistory(trimmed);
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _saveToHistory(String query) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    try {
      if (user != null) {
        await ref
            .read(firestoreServiceProvider)
            .addToSearchHistory(user.uid, query);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('guest_search_history');
        final List<dynamic> list = raw != null ? jsonDecode(raw) : [];
        list.removeWhere((e) => e['query'] == query);
        list.insert(0, {
          'query': query,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await prefs.setString(
            'guest_search_history', jsonEncode(list.take(20).toList()));
      }
      ref.invalidate(searchHistoryProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filters = ref.watch(filterProvider);
    final userAsync = ref.watch(currentUserProvider);

    // Clear controller reactively — never mutate controller state directly in build.
    ref.listen(searchQueryProvider, (_, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      }
    });

    final hasActiveFilters = filters.hasActiveFilters;

    // Build tab list — unified "Top" tab is always first, then enabled sources.
    final tabs = [
      (Icons.auto_awesome_rounded, 'Top', _SourceTab.all),
      if (filters.youtubeEnabled)
        (Icons.play_circle_outline, 'YouTube', _SourceTab.youtube),
      if (filters.redditEnabled)
        (Icons.reddit, 'Reddit', _SourceTab.reddit),
      if (filters.newsEnabled)
        (Icons.newspaper_outlined, 'News', _SourceTab.news),
      if (filters.githubEnabled)
        (Icons.code_rounded, 'GitHub', _SourceTab.github),
    ];

    return FloatingOrbsBackground(
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
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
            titleSpacing: 16,
            title: _AnimatedSearchBar(
              controller: _controller,
              focusNode: _focusNode,
              focused: _searchFocused,
              query: query,
              onSubmitted: _submit,
              onClear: _clear,
            ),
            actions: [
              // Pin current query as a saved dashboard
              if (query.isNotEmpty)
                Consumer(builder: (context, ref, _) {
                  final isPinned = ref
                      .watch(savedDashboardsProvider.notifier)
                      .isPinned(query);
                  return IconButton(
                    tooltip: isPinned ? 'Unpin dashboard' : 'Pin as dashboard',
                    icon: Icon(isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined),
                    color: isPinned ? _accent : null,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final notifier =
                          ref.read(savedDashboardsProvider.notifier);
                      if (isPinned) {
                        notifier.unpin(query);
                      } else {
                        notifier.pin(query);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('"$query" pinned as dashboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                }),
              IconButton(
                tooltip: 'Filters',
                icon: Badge(
                  isLabelVisible: hasActiveFilters,
                  backgroundColor: _accent,
                  child: const Icon(Icons.tune_outlined),
                ),
                onPressed: () => showFilterSheet(context),
              ),
              IconButton(
                tooltip: 'Profile',
                icon: userAsync.maybeWhen(
                  data: (user) => user?.profilePicUrl != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              NetworkImage(user!.profilePicUrl!),
                        )
                      : const Icon(Icons.account_circle_outlined),
                  orElse: () =>
                      const Icon(Icons.account_circle_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
            bottom: TabBar(
              indicatorColor: AppTheme.gradientMid,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppTheme.gradientMid,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              dividerColor: Colors.transparent,
              tabs: tabs
                  .map((t) => Tab(icon: Icon(t.$1, size: 18), text: t.$2))
                  .toList(),
            ),
          ),
          body: query.isEmpty
              ? _EmptySearch(onQuerySelected: (q) {
                  _controller.text = q;
                  _submit(q);
                })
              : TabBarView(
                  children: tabs
                      .map((t) => _SourceTab(provider: t.$3))
                      .toList(),
                ),
        ),
      ),
    );
  }
}

// ── Animated search bar with pulsing gradient border ─────────────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String query;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _AnimatedSearchBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.query,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
      animation: _pulseAnim,
      builder: (_, _) {
        return Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: widget.focused
                ? LinearGradient(
                    colors: [
                      AppTheme.gradientStart
                          .withValues(alpha: _pulseAnim.value * 0.9),
                      AppTheme.gradientMid
                          .withValues(alpha: _pulseAnim.value * 0.9),
                      AppTheme.gradientEnd
                          .withValues(alpha: _pulseAnim.value * 0.9),
                    ],
                  )
                : null,
            border: widget.focused
                ? null
                : Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                    width: 1),
          ),
          padding:
              widget.focused ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
          child: Builder(builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            final isDark =
                Theme.of(context).brightness == Brightness.dark;
            final barColor = isDark
                ? const Color(0xFF12121A)
                : scheme.surfaceContainerHighest;
            final onBar = isDark ? Colors.white : scheme.onSurface;
            final onBarMuted =
                isDark ? Colors.white38 : scheme.onSurfaceVariant;
            return Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius:
                    BorderRadius.circular(widget.focused ? 22.5 : 24),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
                style: TextStyle(color: onBar, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search YouTube, Reddit, News, GitHub...',
                  hintStyle: TextStyle(color: onBarMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: onBarMuted, size: 20),
                  suffixIcon: widget.query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: onBarMuted, size: 18),
                          onPressed: widget.onClear,
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                  filled: false,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Per-source tab ───────────────────────────────────────────────────────────

class _SourceTab extends ConsumerWidget {
  static const all = -1; // unified TrendEngine-ranked results
  static const youtube = 0;
  static const reddit = 1;
  static const news = 2;
  static const github = 3;

  final int provider;
  const _SourceTab({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch (provider) {
      all => ref.watch(unifiedSearchProvider),
      youtube => ref.watch(youtubeSearchProvider),
      reddit => ref.watch(redditSearchProvider),
      github => ref.watch(githubSearchProvider),
      _ => ref.watch(newsSearchProvider),
    };

    final sourceName = switch (provider) {
      all => 'Top Results',
      youtube => 'YouTube',
      reddit => 'Reddit',
      github => 'GitHub',
      _ => 'News',
    };

    return async.when(
      loading: () => const _Shimmer(),
      error: (e, _) => _SearchError(
        message: e.toString(),
        onRetry: () => switch (provider) {
          all => ref.invalidate(unifiedSearchProvider),
          youtube => ref.invalidate(youtubeSearchProvider),
          reddit => ref.invalidate(redditSearchProvider),
          github => ref.invalidate(githubSearchProvider),
          _ => ref.invalidate(newsSearchProvider),
        },
      ),
      data: (items) {
        if (items.isEmpty) return _NoResults(source: sourceName);
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => StaggeredListItem(
            index: i,
            child: TrendCard(item: items[i]),
          ),
        );
      },
    );
  }
}

// ── Empty state with recent searches ────────────────────────────────────────

class _EmptySearch extends ConsumerWidget {
  final ValueChanged<String> onQuerySelected;

  const _EmptySearch({required this.onQuerySelected});

  Future<void> _clearSearchHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear recent searches?'),
        content: const Text('This will remove all recent search entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      await ref.read(firestoreServiceProvider).clearSearchHistory(user.uid);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('guest_search_history');
    }
    ref.invalidate(searchHistoryProvider);
  }

  Future<void> _removeFromHistory(WidgetRef ref, String query) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      await ref
          .read(firestoreServiceProvider)
          .removeFromSearchHistory(user.uid, query);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('guest_search_history');
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .where((e) => e is Map && e['query'] != query)
            .toList();
        await prefs.setString('guest_search_history', jsonEncode(list));
      }
    }
    ref.invalidate(searchHistoryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(searchHistoryProvider);
    final pinnedDashboards = ref.watch(savedDashboardsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saved Dashboards ───────────────────────────────────────────
          if (pinnedDashboards.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 15, color: _accent),
                  const SizedBox(width: 6),
                  Text(
                    'Saved Dashboards',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: pinnedDashboards.map((q) {
                return InputChip(
                  avatar: const Icon(Icons.push_pin, size: 14, color: _accent),
                  label: Text(q),
                  backgroundColor:
                      _accent.withValues(alpha: 0.08),
                  side: BorderSide(
                      color: _accent.withValues(alpha: 0.3)),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  onPressed: () => onQuerySelected(q),
                  onDeleted: () =>
                      ref.read(savedDashboardsProvider.notifier).unpin(q),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  deleteIconColor: theme.colorScheme.onSurfaceVariant,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
          ],

          historyAsync.maybeWhen(
            data: (history) {
              if (history.isEmpty) return const SizedBox.shrink();
              final recent = history.take(5).toList();
              final theme = Theme.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          'Recent Searches',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _clearSearchHistory(context, ref),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: recent.map((item) {
                      final q = item['query'] as String? ?? '';
                      return InputChip(
                        avatar: Icon(Icons.history,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        label: Text(q),
                        onPressed: () => onQuerySelected(q),
                        onDeleted: () => _removeFromHistory(ref, q),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        deleteIconColor: theme.colorScheme.onSurfaceVariant,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // ── Recently Viewed ────────────────────────────────────────────
          _RecentlyViewedSection(),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Icon(Icons.travel_explore,
                      size: 72, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search across all platforms',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'YouTube \u00B7 Reddit \u00B7 News \u00B7 GitHub',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer loading ──────────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, _) => const GradientSkeletonPost(),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String source;
  const _NoResults({required this.source});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No $source results found',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Recently Viewed section ───────────────────────────────────────────────────

const _rvSourceColors = {
  TrendSource.youtube:     Color(0xFFFF0000),
  TrendSource.reddit:      Color(0xFFFF4500),
  TrendSource.news:        Color(0xFF1565C0),
  TrendSource.github:      Color(0xFF238636),
  TrendSource.hackerNews:  Color(0xFFFF6600),
  TrendSource.productHunt: Color(0xFFDA552F),
  TrendSource.devTo:       Color(0xFF0A0A0A),
};

const _rvSourceIcons = {
  TrendSource.youtube:     Icons.play_circle_outline,
  TrendSource.reddit:      Icons.chat_bubble_outline,
  TrendSource.news:        Icons.newspaper_outlined,
  TrendSource.github:      Icons.code,
  TrendSource.hackerNews:  Icons.whatshot_outlined,
  TrendSource.productHunt: Icons.rocket_launch_outlined,
  TrendSource.devTo:       Icons.developer_mode_outlined,
};

class _RecentlyViewedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recentlyViewedProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final recent = items.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Recently Viewed',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () =>
                  ref.read(recentlyViewedProvider.notifier).clear(),
              child: Text(
                'Clear',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recent.map((item) {
          final color = _rvSourceColors[item.source] ?? Colors.grey;
          final icon = _rvSourceIcons[item.source] ?? Icons.public;
          return InkWell(
            onTap: () => LinkOpener.open(context, item.url),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SearchError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SearchError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Search failed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
