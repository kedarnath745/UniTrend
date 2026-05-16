import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_state.dart';
import '../providers/filter_provider.dart';
import '../providers/user_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/youtube_provider.dart';
import '../providers/reddit_provider.dart';
import '../providers/news_provider.dart';
import '../providers/github_provider.dart';
import '../services/firestore_service.dart';

const _accent = Color(0xFFFF5722);

void showFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _FilterSheet(),
  );
}

// ── Step values for sliders ───────────────────────────────────────────────────

const _ytSteps = [0, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000];
const _rdSteps = [0, 100, 500, 1000, 5000, 10000, 50000, 100000];
const _ghStarSteps = [0, 10, 50, 100, 500, 1000, 5000, 10000];

int _nearestStepIndex(List<int> steps, int value) {
  for (int i = 0; i < steps.length; i++) {
    if (steps[i] >= value) return i;
  }
  return steps.length - 1;
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late FilterState _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(filterProvider);
  }

  void _togglePlatform(String p) {
    final updated = Set<String>.from(_local.enabledPlatforms);
    if (updated.contains(p)) {
      if (updated.length > 1) updated.remove(p);
    } else {
      updated.add(p);
    }
    setState(() => _local = _local.copyWith(enabledPlatforms: updated));
  }

  void _toggleLanguage(String lang) {
    final updated = Set<String>.from(_local.githubLanguages);
    updated.contains(lang) ? updated.remove(lang) : updated.add(lang);
    setState(() => _local = _local.copyWith(githubLanguages: updated));
  }

  void _toggleNewsSource(String src) {
    final current = Set<String>.from(_local.resolvedNewsSources);
    if (current.contains(src)) {
      if (current.length > 1) current.remove(src);
    } else {
      current.add(src);
    }
    final next =
        current.length == kAllNewsSources.length ? <String>{} : current;
    setState(() => _local = _local.copyWith(enabledNewsSources: next));
  }

  Future<void> _apply() async {
    final age = ref.read(currentUserProvider).valueOrNull?.age ?? 0;
    final effective =
        (age > 0 && age < 18) ? _local.copyWith(safeSearch: true) : _local;

    ref.read(filterProvider.notifier).applyFromMap(effective.toMap());

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      await FirestoreService()
          .saveUserPreferences(user.uid, {'filters': effective.toMap()});
    } else {
      await ref.read(filterProvider.notifier).saveLocally();
    }

    ref.invalidate(feedProvider);
    ref.invalidate(youtubeTrendingProvider);
    ref.invalidate(redditTrendingProvider);
    ref.invalidate(newsTrendingProvider);
    ref.invalidate(githubTrendingProvider);

    if (mounted) Navigator.pop(context);
  }

  void _reset() => setState(() => _local = const FilterState());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userAge = ref.watch(currentUserProvider).valueOrNull?.age ?? 0;
    final isMinor = userAge > 0 && userAge < 18;
    final activeCount = _countActiveFilters();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: _accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount active',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset all'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scroll,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Sort by ─────────────────────────────────────────────
                _SectionHeader(label: 'Sort by'),
                Row(
                  children: [
                    _ChoiceButton(
                      label: 'Best Match',
                      icon: Icons.auto_awesome_outlined,
                      selected: _local.sortOrder == SortOrder.score,
                      onTap: () => setState(() => _local =
                          _local.copyWith(sortOrder: SortOrder.score)),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceButton(
                      label: 'Most Recent',
                      icon: Icons.schedule_outlined,
                      selected: _local.sortOrder == SortOrder.date,
                      onTap: () => setState(() => _local =
                          _local.copyWith(sortOrder: SortOrder.date)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Platforms ────────────────────────────────────────────
                _SectionHeader(label: 'Platforms'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PlatformChip(
                      label: 'YouTube',
                      icon: Icons.play_circle_filled,
                      color: const Color(0xFFFF0000),
                      selected: _local.enabledPlatforms.contains('youtube'),
                      onTap: () => _togglePlatform('youtube'),
                    ),
                    _PlatformChip(
                      label: 'Reddit',
                      icon: Icons.reddit,
                      color: const Color(0xFFFF4500),
                      selected: _local.enabledPlatforms.contains('reddit'),
                      onTap: () => _togglePlatform('reddit'),
                    ),
                    _PlatformChip(
                      label: 'News',
                      icon: Icons.newspaper_rounded,
                      color: const Color(0xFF1E88E5),
                      selected: _local.enabledPlatforms.contains('news'),
                      onTap: () => _togglePlatform('news'),
                    ),
                    _PlatformChip(
                      label: 'GitHub',
                      icon: Icons.code_rounded,
                      color: const Color(0xFF238636),
                      selected: _local.enabledPlatforms.contains('github'),
                      onTap: () => _togglePlatform('github'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Date range ───────────────────────────────────────────
                _SectionHeader(label: 'Date range'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _dateChip(DateFilter.any, 'Any time'),
                    _dateChip(DateFilter.last24h, 'Last 24 h'),
                    _dateChip(DateFilter.lastWeek, 'Last week'),
                    _dateChip(DateFilter.lastMonth, 'Last month'),
                  ],
                ),
                const SizedBox(height: 20),

                // ── GitHub ───────────────────────────────────────────────
                if (_local.enabledPlatforms.contains('github')) ...[
                  _SectionHeader(
                    label: 'GitHub',
                    badge: _local.githubLanguages.isNotEmpty ||
                            _local.minGithubStars > 0
                        ? _badgeCount([
                            if (_local.minGithubStars > 0) 1,
                            _local.githubLanguages.length,
                          ].fold(0, (a, b) => a + b))
                        : null,
                  ),
                  _SliderRow(
                    label: 'Min stars',
                    icon: Icons.star_outline_rounded,
                    color: const Color(0xFF238636),
                    steps: _ghStarSteps,
                    currentValue: _local.minGithubStars,
                    onChanged: (v) =>
                        setState(() => _local = _local.copyWith(minGithubStars: v)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Language', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kGithubLanguages.map((lang) {
                      final sel = _local.githubLanguages.contains(lang);
                      return FilterChip(
                        label: Text(lang),
                        selected: sel,
                        onSelected: (_) => _toggleLanguage(lang),
                        selectedColor:
                            const Color(0xFF238636).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF238636),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: sel
                              ? const Color(0xFF238636)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── YouTube ──────────────────────────────────────────────
                if (_local.enabledPlatforms.contains('youtube')) ...[
                  _SectionHeader(
                    label: 'YouTube',
                    badge: _local.minYoutubeViews > 0
                        ? _badgeCount(1)
                        : null,
                  ),
                  _SliderRow(
                    label: 'Min views',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFFFF0000),
                    steps: _ytSteps,
                    currentValue: _local.minYoutubeViews,
                    onChanged: (v) => setState(
                        () => _local = _local.copyWith(minYoutubeViews: v)),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Reddit ───────────────────────────────────────────────
                if (_local.enabledPlatforms.contains('reddit')) ...[
                  _SectionHeader(
                    label: 'Reddit',
                    badge: _local.minRedditUpvotes > 0
                        ? _badgeCount(1)
                        : null,
                  ),
                  _SliderRow(
                    label: 'Min upvotes',
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFFFF4500),
                    steps: _rdSteps,
                    currentValue: _local.minRedditUpvotes,
                    onChanged: (v) => setState(
                        () => _local = _local.copyWith(minRedditUpvotes: v)),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── News sources ─────────────────────────────────────────
                if (_local.enabledPlatforms.contains('news')) ...[
                  _SectionHeader(
                    label: 'News sources',
                    badge: _local.enabledNewsSources.isNotEmpty
                        ? _badgeCount(
                            kAllNewsSources.length -
                                _local.resolvedNewsSources.length)
                        : null,
                  ),
                  ...kAllNewsSources.map((src) {
                    final enabled =
                        _local.resolvedNewsSources.contains(src);
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title:
                          Text(src, style: const TextStyle(fontSize: 14)),
                      value: enabled,
                      activeThumbColor: const Color(0xFF1E88E5),
                      activeTrackColor:
                          const Color(0xFF1E88E5).withValues(alpha: 0.4),
                      onChanged: (_) => _toggleNewsSource(src),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Tech aggregators grouped under News
                  const Text('Tech aggregators',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PlatformChip(
                        label: 'Hacker News',
                        icon: Icons.terminal_rounded,
                        color: const Color(0xFFFF6600),
                        selected: _local.enabledPlatforms.contains('hackerNews'),
                        onTap: () => _togglePlatform('hackerNews'),
                      ),
                      _PlatformChip(
                        label: 'Product Hunt',
                        icon: Icons.rocket_launch_rounded,
                        color: const Color(0xFFDA552F),
                        selected: _local.enabledPlatforms.contains('productHunt'),
                        onTap: () => _togglePlatform('productHunt'),
                      ),
                      _PlatformChip(
                        label: 'Dev.to',
                        icon: Icons.article_rounded,
                        color: const Color(0xFFB0BEC5),
                        selected: _local.enabledPlatforms.contains('devTo'),
                        onTap: () => _togglePlatform('devTo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Safe search ──────────────────────────────────────────
                _SectionHeader(label: 'Content'),
                if (isMinor)
                  _InfoBanner(
                    icon: Icons.child_care_rounded,
                    color: Colors.orange,
                    message: 'Safe search is always on for your age group.',
                  )
                else
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _accent,
                    activeTrackColor: _accent.withValues(alpha: 0.4),
                    value: _local.safeSearch,
                    onChanged: (v) =>
                        setState(() => _local = _local.copyWith(safeSearch: v)),
                    title: const Text('Safe Search'),
                    subtitle: const Text(
                        'Filter explicit content across all platforms',
                        style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Apply button ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                  top: BorderSide(
                      color:
                          scheme.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Apply Filters',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(DateFilter f, String label) {
    final sel = _local.dateFilter == f;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: _accent.withValues(alpha: 0.15),
      checkmarkColor: _accent,
      labelStyle: TextStyle(
        color: sel ? _accent : Theme.of(context).colorScheme.onSurface,
        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (_) =>
          setState(() => _local = _local.copyWith(dateFilter: f)),
    );
  }

  int _countActiveFilters() {
    var n = 0;
    if (_local.enabledPlatforms.length < 7) n++;
    if (_local.sortOrder != SortOrder.score) n++;
    if (_local.dateFilter != DateFilter.any) n++;
    if (_local.minYoutubeViews > 0) n++;
    if (_local.minRedditUpvotes > 0) n++;
    if (_local.minGithubStars > 0) n++;
    if (_local.githubLanguages.isNotEmpty) n++;
    if (_local.enabledNewsSources.isNotEmpty) n++;
    if (_local.safeSearch) n++;
    return n;
  }

  Widget _badgeCount(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$n',
          style: const TextStyle(
              color: _accent, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? badge;

  const _SectionHeader({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? _accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? _accent : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? _accent : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16, color: selected ? color : null),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected
            ? color
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.5)
            : Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
      ),
    );
  }
}

/// Slider that snaps to a predefined list of integer steps.
class _SliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<int> steps;
  final int currentValue;
  final ValueChanged<int> onChanged;

  const _SliderRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.steps,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final idx = _nearestStepIndex(steps, currentValue);
    final display = _fmt(steps[idx]);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          display,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: steps[idx] > 0 ? color : null),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 180,
          child: Slider(
            value: idx.toDouble(),
            min: 0,
            max: (steps.length - 1).toDouble(),
            divisions: steps.length - 1,
            activeColor: color,
            label: display,
            onChanged: (v) => onChanged(steps[v.round()]),
          ),
        ),
      ],
    );
  }

  String _fmt(int v) {
    if (v == 0) return 'Any';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
