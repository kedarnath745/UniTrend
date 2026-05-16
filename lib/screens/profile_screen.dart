import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../providers/notification_prefs_provider.dart';
import '../providers/personalization_prefs_provider.dart';
import '../providers/personalization_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_orbs_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/staggered_list_item.dart';
import 'auth/login_screen.dart';
import 'main_shell.dart';

const _accent = Color(0xFFFF5722);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
      ),
      body: FloatingOrbsBackground(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user != null) return _ProfileBody(user: user);

            // Anonymous / guest Firebase user
            final isGuest = authAsync.valueOrNull?.isAnonymous ?? false;
            if (isGuest) return const _GuestProfileBody();

            return const Center(child: Text('Not logged in'));
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final UserModel user;
  const _ProfileBody({required this.user});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody>
    with SingleTickerProviderStateMixin {
  bool _uploadingPic = false;
  File? _localProfilePic;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  static String _localPicKey(String uid) => 'local_profile_pic_$uid';

  @override
  void initState() {
    super.initState();
    _loadLocalPic();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0, end: 1).animate(_ringCtrl);
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalPic() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_localPicKey(widget.user.uid));
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _localProfilePic = File(path));
    }
  }

  Future<void> _changeProfilePic() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPic = true);
    try {
      final file = File(picked.path);

      // Upload to Firebase Storage and update Firestore + Auth profile.
      final url = await ref
          .read(authServiceProvider)
          .uploadProfileImage(widget.user.uid, file);
      await ref
          .read(firestoreServiceProvider)
          .updateProfilePic(widget.user.uid, url);
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
      ref.invalidate(currentUserProvider);

      // Also cache locally for instant display.
      final appDir = await getApplicationDocumentsDirectory();
      final localPath =
          '${appDir.path}/profile_pic_${widget.user.uid}.jpg';
      await file.copy(localPath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localPicKey(widget.user.uid), localPath);

      if (mounted) setState(() => _localProfilePic = File(localPath));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPic = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Are you sure you want to sign out of UniTrend?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This will permanently delete your account and all data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(authServiceProvider)
          .deleteAccount(widget.user.uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Animated gradient ring avatar ─────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: _changeProfilePic,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, _) => Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        startAngle: _ringAnim.value * 6.283,
                        colors: const [
                          Color(0xFFFF6B35),
                          Color(0xFFE94B9C),
                          Color(0xFF7B61FF),
                          Color(0xFF00D4FF),
                          Color(0xFFFF6B35),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                      backgroundImage: _localProfilePic != null
                          ? FileImage(_localProfilePic!)
                              as ImageProvider
                          : user.profilePicUrl != null
                              ? CachedNetworkImageProvider(
                                  user.profilePicUrl!)
                              : null,
                      child: _localProfilePic == null &&
                              user.profilePicUrl == null
                          ? Icon(Icons.person,
                              size: 52,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)
                          : null,
                    ),
                  ),
                ),
                if (_uploadingPic)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            user.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Center(
          child: Text(
            user.email ?? user.phone ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Account details glass card ─────────────────────────────────────
        _SectionHeader(label: 'Account Details'),
        GlassCard(
          child: Column(
            children: [
              if (user.email != null)
                _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email!),
              if (user.phone != null)
                _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user.phone!),
              if (user.dateOfBirth != null)
                _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Date of Birth',
                    value: DateFormat('MMMM d, yyyy')
                        .format(user.dateOfBirth!)),
              _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since',
                  value:
                      DateFormat('MMM yyyy').format(user.createdAt)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Search history ─────────────────────────────────────────────────
        _SearchHistorySection(uid: user.uid),

        const SizedBox(height: 20),

        // ── Appearance glass card ──────────────────────────────────────────
        _SectionHeader(label: 'Appearance'),
        GlassCard(
          child: _ThemeToggleTile(),
        ),

        const SizedBox(height: 20),

        // ── Notification settings ──────────────────────────────────────────
        _SectionHeader(label: 'Notifications'),
        GlassCard(child: const _NotificationPrefsTile()),

        const SizedBox(height: 20),

        // ── Personalized Feed settings ──────────────────────────────────────
        const _FeedPersonalizationSection(),

        const SizedBox(height: 20),

        // ── Logout ─────────────────────────────────────────────────────────
        GlassCard(
          onTap: _logout,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Icon(Icons.logout,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Delete account ─────────────────────────────────────────────────
        TextButton(
          onPressed: _deleteAccount,
          child: const Text('Delete Account',
              style: TextStyle(color: Color(0xFFEF5350))),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Guest Profile Body ────────────────────────────────────────────────────────

class _GuestProfileBody extends ConsumerWidget {
  const _GuestProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Icon(Icons.person_outline,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Guest',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Center(
          child: Text(
            'Browsing as guest',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),

        const SizedBox(height: 28),

        // Appearance
        _SectionHeader(label: 'Appearance'),
        GlassCard(child: _ThemeToggleTile()),

        const SizedBox(height: 20),

        // Notifications
        _SectionHeader(label: 'Notifications'),
        GlassCard(child: const _NotificationPrefsTile()),

        const SizedBox(height: 20),

        // Personalized Feed settings
        const _FeedPersonalizationSection(),

        const SizedBox(height: 24),

        // Sign in CTA
        GlassCard(
          onTap: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Icon(Icons.login, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Text(
                    'Sign In to unlock all features',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Search History Section ────────────────────────────────────────────────────

class _SearchHistorySection extends ConsumerWidget {
  final String uid;
  const _SearchHistorySection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(searchHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(label: 'Search History'),
            const Spacer(),
            historyAsync.maybeWhen(
              data: (history) => history.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear history?'),
                            content: const Text(
                                'Remove all search history?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _accent),
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(firestoreServiceProvider)
                              .clearSearchHistory(uid);
                          ref.invalidate(searchHistoryProvider);
                        }
                      },
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.accentGradient
                                .createShader(bounds),
                        child: const Text('Clear all',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load: $e',
              style: const TextStyle(color: Colors.red)),
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No search history yet',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return GlassCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                itemBuilder: (ctx, i) {
                  final item = history[i];
                  final query = item['query'] as String? ?? '';
                  final ts = item['timestamp'];
                  String timeStr = '';
                  if (ts is Timestamp) {
                    timeStr = _formatTime(ts.toDate());
                  }

                  return StaggeredListItem(
                    index: i,
                    child: Dismissible(
                      key: Key('$query$i'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.withValues(alpha: 0.12),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red),
                      ),
                      onDismissed: (_) {
                        ref.invalidate(searchHistoryProvider);
                        ref
                            .read(firestoreServiceProvider)
                            .removeFromSearchHistory(uid, query);
                      },
                      child: ListTile(
                        leading: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.accentGradient
                                  .createShader(bounds),
                          child: const Icon(Icons.history,
                              size: 20, color: Colors.white),
                        ),
                        title: Text(query,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.onSurface,
                                fontSize: 14)),
                        subtitle: timeStr.isNotEmpty
                            ? Text(timeStr,
                                style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                    fontSize: 12))
                            : null,
                        trailing: Icon(Icons.north_west,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        onTap: () {
                          ref
                              .read(searchQueryProvider.notifier)
                              .state = query;
                          ref
                              .read(navIndexProvider.notifier)
                              .state = 1;
                          Navigator.of(ctx)
                              .popUntil((r) => r.isFirst);
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ShaderMask(
        shaderCallback: (bounds) =>
            AppTheme.accentGradient.createShader(bounds),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
      title: Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12)),
      subtitle: Text(value,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      dense: true,
    );
  }
}

// ── Curated topic catalogue ───────────────────────────────────────────────────

const _topicCatalogue = <String, List<({String label, String icon})>>{
  'Technology': [
    (label: 'Artificial Intelligence', icon: '🤖'),
    (label: 'Cybersecurity', icon: '🔐'),
    (label: 'Open Source', icon: '🛠'),
    (label: 'Web Development', icon: '🌐'),
    (label: 'Mobile Dev', icon: '📱'),
    (label: 'Cloud Computing', icon: '☁️'),
    (label: 'DevOps', icon: '⚙️'),
    (label: 'Data Science', icon: '📊'),
  ],
  'Finance': [
    (label: 'Crypto', icon: '₿'),
    (label: 'Stocks', icon: '📈'),
    (label: 'Startups', icon: '🚀'),
    (label: 'VC & Funding', icon: '💰'),
    (label: 'Personal Finance', icon: '💳'),
  ],
  'Science': [
    (label: 'Space', icon: '🌌'),
    (label: 'Health & Medicine', icon: '🧬'),
    (label: 'Climate', icon: '🌱'),
    (label: 'Physics', icon: '⚛️'),
  ],
  'Entertainment': [
    (label: 'Gaming', icon: '🎮'),
    (label: 'Movies & TV', icon: '🎬'),
    (label: 'Music', icon: '🎵'),
    (label: 'Esports', icon: '🏆'),
  ],
  'Business & Society': [
    (label: 'Politics', icon: '🏛'),
    (label: 'Business', icon: '💼'),
    (label: 'Design & UX', icon: '🎨'),
    (label: 'Sports', icon: '⚽'),
  ],
};

// ── Feed Personalization Section ──────────────────────────────────────────────

class _FeedPersonalizationSection extends ConsumerStatefulWidget {
  const _FeedPersonalizationSection();

  @override
  ConsumerState<_FeedPersonalizationSection> createState() =>
      _FeedPersonalizationSectionState();
}

class _FeedPersonalizationSectionState
    extends ConsumerState<_FeedPersonalizationSection> {

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset feed signals?'),
        content: const Text(
          'This clears all your likes, dislikes, and bookmark signals. '
          'Explicit interests you pinned will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Invalidate the feedback + personalization profile so it rebuilds clean
    ref.invalidate(personalizationProfileProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feed signals cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(personalizationPrefsProvider);
    final notifier = ref.read(personalizationPrefsProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Personalized Feed'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Master toggle ────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.accentGradient.createShader(b),
                      child: const Icon(Icons.tune_rounded,
                          size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalise my feed',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            prefs.enabled
                                ? 'Stories ranked by your interests'
                                : 'Showing pure trending order',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: prefs.enabled,
                      onChanged: (_) => notifier.toggle(),
                      activeThumbColor: _accent,
                      activeTrackColor: _accent.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),

              if (prefs.enabled) ...[
                Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4)),

                // ── Topic picker ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Your Interests',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (prefs.interests.isNotEmpty)
                        GestureDetector(
                          onTap: notifier.clearInterests,
                          child: Text(
                            'Clear all',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),

                if (prefs.interests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Select topics below — stories about them will always rank higher.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ),

                // Topic catalogue by category
                ..._topicCatalogue.entries.map((cat) =>
                    _TopicCategory(
                      category: cat.key,
                      topics: cat.value,
                      selected: prefs.interests,
                      onToggle: (topic) {
                        prefs.interests.contains(topic)
                            ? notifier.removeInterest(topic)
                            : notifier.addInterest(topic);
                      },
                    )),

                // ── Reset implicit signals ────────────────────────────
                Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4)),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  title: Text(
                    'Reset implicit signals',
                    style: TextStyle(
                        fontSize: 13, color: theme.colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    'Clears likes, dislikes & bookmark influence',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  onTap: _confirmReset,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Topic category row ────────────────────────────────────────────────────────

class _TopicCategory extends StatelessWidget {
  final String category;
  final List<({String label, String icon})> topics;
  final List<String> selected;
  final void Function(String topic) onToggle;

  const _TopicCategory({
    required this.category,
    required this.topics,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.55),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: topics.map((t) {
              final isSelected = selected
                  .contains(t.label.toLowerCase());
              return FilterChip(
                label: Text('${t.icon}  ${t.label}'),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isSelected
                      ? _accent
                      : theme.colorScheme.onSurface,
                ),
                selected: isSelected,
                onSelected: (_) => onToggle(t.label),
                checkmarkColor: _accent,
                selectedColor: _accent.withValues(alpha: 0.12),
                backgroundColor: theme.colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                side: BorderSide(
                  color: isSelected
                      ? _accent.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                  width: isSelected ? 1.5 : 1,
                ),
                showCheckmark: false,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeProvider);

    final options = [
      (AppThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (AppThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      (AppThemeMode.amoled, Icons.nights_stay_outlined, 'AMOLED'),
      (AppThemeMode.system, Icons.brightness_auto_outlined, 'Auto'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: const Icon(Icons.palette_outlined,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Theme',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor:
                  AppTheme.gradientMid.withValues(alpha: 0.2),
              selectedForegroundColor: AppTheme.gradientMid,
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              minimumSize: const Size.fromHeight(36),
              side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5)),
            ),
            segments: options
                .map((o) => ButtonSegment<AppThemeMode>(
                      value: o.$1,
                      icon: Icon(o.$2, size: 16),
                      label: Text(o.$3),
                    ))
                .toList(),
            selected: {appThemeMode},
            onSelectionChanged: (set) =>
                ref.read(themeProvider.notifier).setTheme(set.first),
          ),
          if (appThemeMode == AppThemeMode.amoled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pure black — saves battery on OLED screens',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Notification Preferences Tile ─────────────────────────────────────────────

const _kNotifPurple = Color(0xFF7B61FF);

class _NotificationPrefsTile extends ConsumerWidget {
  const _NotificationPrefsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: const Icon(Icons.notifications_outlined,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Notifications',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          _NotifSwitch(
            label: '🚀 Breakout alerts',
            subtitle: 'Score jumps >25 pts',
            value: prefs.velocityAlerts,
            onChanged: notifier.setVelocityAlerts,
          ),
          _NotifSwitch(
            label: '🌅 Morning digest',
            subtitle: 'Daily briefing at ${prefs.digestHour}:00',
            value: prefs.morningDigest,
            onChanged: notifier.setMorningDigest,
          ),
          if (prefs.morningDigest)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    'Digest time:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _kNotifPurple,
                        thumbColor: _kNotifPurple,
                        inactiveTrackColor: _kNotifPurple.withValues(alpha: 0.2),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                      ),
                      child: Slider(
                        value: prefs.digestHour.toDouble(),
                        min: 5,
                        max: 12,
                        divisions: 7,
                        label: '${prefs.digestHour}:00',
                        onChanged: (v) =>
                            notifier.setDigestHour(v.round()),
                      ),
                    ),
                  ),
                  Text(
                    '${prefs.digestHour}:00',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _kNotifPurple,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          _NotifSwitch(
            label: '👁 Watchlist alerts',
            subtitle: 'When followed topics spike',
            value: prefs.watchlistAlerts,
            onChanged: notifier.setWatchlistAlerts,
          ),
        ],
      ),
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitch({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _kNotifPurple,
          activeTrackColor: _kNotifPurple.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}
