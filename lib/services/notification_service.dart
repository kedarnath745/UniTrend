import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Item IDs we've already notified about this session — prevents re-firing
  /// on every feed refresh.
  static final _notifiedIds = <String>{};

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Request the runtime permission (required on Android 13+).
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Fires a high-importance notification only if [itemId] hasn't been
  /// notified yet this session.
  static Future<void> maybeNotify({
    required String itemId,
    required String keyword,
    required String title,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_notifiedIds.contains(itemId)) return; // already fired — skip
    if (!_initialized) await init();

    _notifiedIds.add(itemId);

    const androidDetails = AndroidNotificationDetails(
      'watchlist_alerts',
      'Watchlist Alerts',
      channelDescription: 'Alerts when a followed topic is trending',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      itemId.hashCode,
      '#$keyword is trending',
      title,
      const NotificationDetails(android: androidDetails),
    );
  }
}
