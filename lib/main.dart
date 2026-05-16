import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart' show AppThemeMode, themeProvider;
import 'screens/auth/splash_screen.dart';
import 'services/background_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  if (!kIsWeb && !Platform.isWindows) {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
    // Must be registered before runApp, after Firebase.initializeApp.
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  }
  await NotificationService.init();
  final container = ProviderContainer();
  await container.read(themeProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const UniTrendApp()));

  // Deferred: non-critical background setup after first frame to shave
  // startup latency. These do not affect initial UI rendering.
  Future<void>.delayed(const Duration(milliseconds: 800), () async {
    await FcmService.init();
    await BackgroundService.init();
    await BackgroundService.scheduleWatchlistCheck();
    await BackgroundService.scheduleMorningDigest();
  });
}

class UniTrendApp extends ConsumerWidget {
  const UniTrendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final darkTheme = appThemeMode == AppThemeMode.amoled
        ? AppTheme.buildAmoledTheme()
        : AppTheme.buildDarkTheme();
    return MaterialApp(
      title: 'UniTrend',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: darkTheme,
      themeMode: notifier.flutterThemeMode,
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    // Orange-red accent (deep orange)
    const seedColor = Color(0xFFFF5722);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: seedColor.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: seedColor);
          }
          return null;
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: seedColor,
              fontSize: 12,
            );
          }
          return GoogleFonts.inter(fontSize: 12);
        }),
      ),
    );
  }
}
