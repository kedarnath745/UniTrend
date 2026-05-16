import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show max;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed_revised/webfeed_revised.dart';
import 'package:workmanager/workmanager.dart';
import 'groq_service.dart';

const _taskUniqueName      = 'unitrend_watchlist_bg_check';
const _taskName            = 'unitrend.watchlist.check';
const _morningUniqueName   = 'unitrend_morning_digest';
const _morningTaskName     = 'unitrend.morning.digest';

// ── Top-level callback (required by Workmanager) ──────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    if (taskName == _taskName) {
      try {
        await runWatchlistCheck();
        await runVelocityCheck();
      } catch (_) {}
    } else if (taskName == _morningTaskName) {
      try {
        await runMorningDigest();
      } catch (_) {}
    }
    return true;
  });
}

// ── SharedPreferences keys ────────────────────────────────────────────────────

const _notifiedHashesKey    = 'unitrend_bg_notified_hashes';
const _velocityNotifiedKey  = 'unitrend_velocity_notified_v1';
const _scoreSnapshotsKey    = 'unitrend_score_snapshots_v1';

// ── Watchlist keyword check ───────────────────────────────────────────────────

Future<void> runWatchlistCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final keywords = prefs.getStringList('watchlist_keywords') ?? [];
  if (keywords.isEmpty) return;

  final notifiedHashes =
      Set<String>.from(prefs.getStringList(_notifiedHashesKey) ?? []);

  const feedUrls = [
    'https://feeds.bbci.co.uk/news/technology/rss.xml',
    'https://www.reddit.com/r/technology/top/.rss?limit=25',
  ];

  final items = <(String title, String id)>[];
  for (final url in feedUrls) {
    try {
      final res = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'UniTrend/1.0 (background)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final feed = RssFeed.parse(res.body);
        for (final item in feed.items ?? []) {
          final title = item.title ?? '';
          if (title.isEmpty) continue;
          final stableId =
              (item.guid ?? item.link ?? title).hashCode.toString();
          items.add((title, stableId));
        }
      }
    } catch (_) {
      continue;
    }
  }

  if (items.isEmpty) return;

  final newlyNotifiedHashes = <String>{};

  for (final keyword in keywords) {
    final kLower = keyword.toLowerCase();
    for (final (title, id) in items) {
      if (!title.toLowerCase().contains(kLower)) continue;
      if (notifiedHashes.contains(id)) continue;

      await _fireWatchlistNotification(keyword, title);
      newlyNotifiedHashes.add(id);
      break;
    }
  }

  if (newlyNotifiedHashes.isNotEmpty) {
    final updated = {...notifiedHashes, ...newlyNotifiedHashes}.toList();
    final trimmed =
        updated.length > 200 ? updated.sublist(updated.length - 200) : updated;
    await prefs.setStringList(_notifiedHashesKey, trimmed);
  }
}

// ── Velocity Alert: fire when a cluster jumps >25 pts since yesterday ─────────

Future<void> runVelocityCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_scoreSnapshotsKey);
  if (raw == null) return;

  try {
    final list = jsonDecode(raw) as List;
    final now = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Max score per (clusterId, day)
    final todayMax    = <String, double>{};
    final yesterdayMax = <String, double>{};
    final topicByCluster = <String, String>{};

    for (final raw in list) {
      final s = raw as Map<String, dynamic>;
      final clusterId = s['c'] as String;
      final topic     = s['t'] as String;
      final score     = (s['s'] as num).toDouble();
      final ts        = DateTime.fromMillisecondsSinceEpoch(s['ts'] as int);
      final day       = DateTime(ts.year, ts.month, ts.day);

      topicByCluster[clusterId] = topic;

      if (day == today) {
        todayMax[clusterId] = max(todayMax[clusterId] ?? 0.0, score);
      } else if (day == yesterday) {
        yesterdayMax[clusterId] = max(yesterdayMax[clusterId] ?? 0.0, score);
      }
    }

    // Retrieve clusters we already alerted about today to avoid re-firing
    final alreadyAlerted =
        Set<String>.from(prefs.getStringList(_velocityNotifiedKey) ?? []);

    final newlyAlerted = <String>[];

    for (final entry in todayMax.entries) {
      final clusterId = entry.key;
      final current   = entry.value;
      final previous  = yesterdayMax[clusterId] ?? 0.0;
      final delta     = current - previous;

      if (delta > 25 && current > 50 && !alreadyAlerted.contains(clusterId)) {
        final topic = topicByCluster[clusterId] ?? clusterId;
        await _fireVelocityAlert(topic, delta.round());
        newlyAlerted.add(clusterId);
      }
    }

    if (newlyAlerted.isNotEmpty) {
      final updated = {...alreadyAlerted, ...newlyAlerted}.toList();
      await prefs.setStringList(_velocityNotifiedKey, updated);
    }
  } catch (_) {}
}

// ── Morning Digest ────────────────────────────────────────────────────────────

Future<void> runMorningDigest() async {
  const feedUrls = [
    'https://feeds.bbci.co.uk/news/technology/rss.xml',
    'https://feeds.bbci.co.uk/news/business/rss.xml',
    'https://www.reddit.com/r/technology/top/.rss?limit=20',
    'https://hnrss.org/frontpage?count=15',
  ];

  final titles = <String>[];
  for (final url in feedUrls) {
    try {
      final res = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'UniTrend/1.0 (morning-digest)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final feed = RssFeed.parse(res.body);
        for (final item in (feed.items ?? []).take(5)) {
          final t = item.title;
          if (t != null && t.isNotEmpty) titles.add(t);
        }
      }
    } catch (_) {
      continue;
    }
  }

  if (titles.isEmpty) return;

  String digestText;
  try {
    final groq = GroqService();
    final lines = titles
        .take(15)
        .toList()
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    digestText = await groq.generateMorningBriefing(lines);
  } catch (_) {
    // Groq unavailable — fall back to top 3 headlines
    digestText = titles.take(3).join(' • ');
  }

  await _fireMorningDigestNotification(digestText);
}

// ── Notification helpers ──────────────────────────────────────────────────────

Future<FlutterLocalNotificationsPlugin> _initPlugin() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidSettings));
  return plugin;
}

Future<void> _fireWatchlistNotification(String keyword, String title) async {
  final plugin = await _initPlugin();
  const details = AndroidNotificationDetails(
    'watchlist_alerts',
    'Watchlist Alerts',
    channelDescription: 'Alerts when a followed topic is trending',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  await plugin.show(
    keyword.hashCode,
    '#$keyword is trending',
    title,
    const NotificationDetails(android: details),
  );
}

Future<void> _fireVelocityAlert(String topic, int delta) async {
  final plugin = await _initPlugin();
  const details = AndroidNotificationDetails(
    'velocity_alerts',
    'Breakout Alerts',
    channelDescription: 'Fires when a topic score spikes more than 25 points',
    importance: Importance.max,
    priority: Priority.max,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFFFF5722),
    enableLights: true,
    playSound: true,
    ongoing: true,
    autoCancel: false,
  );
  await plugin.show(
    topic.hashCode ^ 0xBEEF,
    '🚨 BREAKOUT: #$topic is exploding!',
    'Score jumped +$delta points since yesterday — trending across multiple sources.',
    const NotificationDetails(android: details),
  );
}

Future<void> _fireMorningDigestNotification(String digest) async {
  final plugin = await _initPlugin();
  final details = AndroidNotificationDetails(
    'morning_digest',
    'Morning Digest',
    channelDescription: 'Daily AI-generated trend briefing delivered at 8 AM',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
    styleInformation: BigTextStyleInformation(
      digest,
      contentTitle: 'Your Morning Trend Briefing ☀️',
      summaryText: 'UniTrend AI Digest',
    ),
  );
  await plugin.show(
    0xD1BE57,
    'Morning Trend Briefing ☀️',
    digest,
    NotificationDetails(android: details),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Duration _delayToNextEightAM() {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, 8, 0, 0);
  if (!target.isAfter(now)) {
    target = target.add(const Duration(days: 1));
  }
  return target.difference(now);
}

// ── Public API ────────────────────────────────────────────────────────────────

class BackgroundService {
  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> scheduleWatchlistCheck() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskName,
      frequency: const Duration(hours: 3),
      initialDelay: const Duration(minutes: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> scheduleMorningDigest() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      _morningUniqueName,
      _morningTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: _delayToNextEightAM(),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().cancelAll();
  }
}
