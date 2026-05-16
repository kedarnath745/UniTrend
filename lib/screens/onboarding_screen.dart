import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_state.dart';
import '../providers/filter_provider.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_orbs_background.dart';

// ── Interest definitions ──────────────────────────────────────────────────────

class _Interest {
  final String label;
  final IconData icon;
  final String keyword;   // added to watchlist
  final FeedCategory? category;

  const _Interest(this.label, this.icon, this.keyword, [this.category]);
}

const _interests = [
  _Interest('Tech & AI',      Icons.memory_outlined,              'technology',    FeedCategory.tech),
  _Interest('Finance',        Icons.trending_up_rounded,          'finance',       FeedCategory.finance),
  _Interest('Gaming',         Icons.sports_esports_outlined,      'gaming',        FeedCategory.gaming),
  _Interest('Startups',       Icons.rocket_launch_outlined,       'startup',       FeedCategory.startups),
  _Interest('Entertainment',  Icons.movie_outlined,               'entertainment', FeedCategory.entertainment),
  _Interest('Science',        Icons.science_outlined,             'science'),
  _Interest('Sports',         Icons.sports_basketball_outlined,   'sports'),
  _Interest('Politics',       Icons.how_to_vote_outlined,         'politics'),
  _Interest('Crypto',         Icons.currency_bitcoin,             'crypto'),
  _Interest('Climate',        Icons.eco_outlined,                 'climate'),
];

// ── Onboarding screen ─────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Page 1 state
  final Set<int> _selectedInterests = {};

  // Page 2 state
  FeedRegion _region = FeedRegion.global;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Apply region
    ref.read(filterProvider.notifier).setRegion(_region);

    // Apply first selected FeedCategory (if any)
    final firstCatInterest = _selectedInterests
        .map((i) => _interests[i])
        .where((i) => i.category != null)
        .firstOrNull;
    if (firstCatInterest != null) {
      ref.read(filterProvider.notifier).setCategory(firstCatInterest.category!);
    }

    // Follow selected interest keywords
    final watchlist = ref.read(watchlistProvider.notifier);
    for (final idx in _selectedInterests) {
      await watchlist.follow(_interests[idx].keyword);
    }

    // Persist filter changes
    await ref.read(filterProvider.notifier).saveLocally();

    // Mark onboarding done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!mounted) return;
    Navigator.of(context).pop(); // return to MainShell (which pushed us)
  }

  @override
  Widget build(BuildContext context) {
    return FloatingOrbsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Progress dots ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // Skip (pages 0 and 1 only)
                    if (_page < 2)
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),

                    const Spacer(),

                    // Step dots
                    ...List.generate(3, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: active ? AppTheme.accentGradient : null,
                          color: active
                              ? null
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                        ),
                      );
                    }),

                    const Spacer(),
                    const SizedBox(width: 60), // balance skip button
                  ],
                ),
              ),

              // ── Pages ───────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (p) => setState(() => _page = p),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _InterestsPage(
                      selected: _selectedInterests,
                      onToggle: (i) =>
                          setState(() {
                            if (_selectedInterests.contains(i)) {
                              _selectedInterests.remove(i);
                            } else {
                              _selectedInterests.add(i);
                            }
                          }),
                    ),
                    _RegionPage(
                      region: _region,
                      onChanged: (r) => setState(() => _region = r),
                    ),
                    const _ReadyPage(),
                  ],
                ),
              ),

              // ── Continue / Get Started button ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _page == 0 && _selectedInterests.isEmpty
                          ? null
                          : _next,
                      child: Text(
                        _page == 2 ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 1: Interests ─────────────────────────────────────────────────────────

class _InterestsPage extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  const _InterestsPage({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
            child: Text(
              'What interests you?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick topics to personalise your feed and watchlist.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_interests.length, (i) {
              final interest = _interests[i];
              final isSelected = selected.contains(i);
              return _InterestChip(
                label: interest.label,
                icon: interest.icon,
                selected: isSelected,
                onTap: () => onToggle(i),
              );
            }),
          ),
          if (selected.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Select at least one to continue',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _InterestChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.accentGradient : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurface,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 2: Region ────────────────────────────────────────────────────────────

class _RegionPage extends StatelessWidget {
  final FeedRegion region;
  final ValueChanged<FeedRegion> onChanged;

  const _RegionPage({required this.region, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
            child: Text(
              'Where are you?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your region fine-tunes news and Reddit sources.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          _RegionCard(
            emoji: '🌐',
            title: 'Global',
            subtitle: 'BBC, Reuters, Al Jazeera + worldwide Reddit',
            selected: region == FeedRegion.global,
            onTap: () => onChanged(FeedRegion.global),
          ),
          const SizedBox(height: 14),
          _RegionCard(
            emoji: '🇮🇳',
            title: 'India',
            subtitle: 'Times of India, NDTV, The Hindu + r/india',
            selected: region == FeedRegion.india,
            onTap: () => onChanged(FeedRegion.india),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RegionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.7)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Page 3: Ready ─────────────────────────────────────────────────────────────

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
            child: const Icon(Icons.bolt, size: 72, color: Colors.white),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
            child: Text(
              "You're all set!",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your feed is personalised. Follow more topics anytime from any card in the feed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FeatureRow(Icons.radar, 'Signal Radar',
              'Hero view of top cross-platform clusters'),
          const SizedBox(height: 12),
          _FeatureRow(Icons.track_changes_rounded, 'Watchlist',
              'Follow keywords — get matched stories'),
          const SizedBox(height: 12),
          _FeatureRow(Icons.push_pin_outlined, 'Saved Dashboards',
              'Pin search queries as instant feeds'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
