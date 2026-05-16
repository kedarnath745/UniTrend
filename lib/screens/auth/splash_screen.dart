import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/filter_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/floating_orbs_background.dart';
import '../main_shell.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
    );

    _scaleCtrl.forward().then((_) => _fadeCtrl.forward());
    _init();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final splashFuture = Future<void>.delayed(const Duration(seconds: 2));

    try {
      await ref.read(filterProvider.notifier).loadFromPrefs();

      if (kIsWeb || Platform.isWindows) {
        await splashFuture;
        if (!mounted) return;
        // Windows has no Firebase support — launch directly as guest into the feed
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => (!kIsWeb && Platform.isWindows)
                ? const MainShell()
                : const LoginScreen(),
          ),
        );
        return;
      }

      final user = await ref.read(authStateProvider.future);

      if (user != null) {
        try {
          final prefs = await ref
              .read(firestoreServiceProvider)
              .getUserPreferences(user.uid);
          final filtersMap = prefs['filters'] as Map<String, dynamic>?;
          if (filtersMap != null) {
            ref.read(filterProvider.notifier).applyFromMap(filtersMap);
            // Persist migrated state (adds new platforms like github) back to Firestore
            final migratedFilters = ref.read(filterProvider).toMap();
            ref.read(firestoreServiceProvider).saveUserPreferences(
                user.uid, {'filters': migratedFilters});
          }
        } catch (_) {}
      }

      await splashFuture;
      if (!mounted) return;
      _navigate(user);
    } catch (_) {
      await splashFuture;
      if (!mounted) return;
      _navigate(null);
    }
  }

  void _navigate(dynamic user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            user != null ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FloatingOrbsBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with elastic scale
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: AppTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gradientMid.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt,
                      size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),

              // Title with fade-in
              FadeTransition(
                opacity: _fadeAnim,
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: Text(
                    'UniTrend',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Tagline fade-in
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  'All your trends in one place',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ),

              const SizedBox(height: 60),

              // Gradient progress indicator
              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.gradientMid),
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
