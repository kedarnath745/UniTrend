import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefs {
  final bool velocityAlerts;
  final bool morningDigest;
  final bool watchlistAlerts;
  final int digestHour; // 0-23

  const NotificationPrefs({
    this.velocityAlerts = true,
    this.morningDigest = true,
    this.watchlistAlerts = true,
    this.digestHour = 8,
  });

  NotificationPrefs copyWith({
    bool? velocityAlerts,
    bool? morningDigest,
    bool? watchlistAlerts,
    int? digestHour,
  }) =>
      NotificationPrefs(
        velocityAlerts: velocityAlerts ?? this.velocityAlerts,
        morningDigest: morningDigest ?? this.morningDigest,
        watchlistAlerts: watchlistAlerts ?? this.watchlistAlerts,
        digestHour: digestHour ?? this.digestHour,
      );

  Map<String, dynamic> toJson() => {
        'velocityAlerts': velocityAlerts,
        'morningDigest': morningDigest,
        'watchlistAlerts': watchlistAlerts,
        'digestHour': digestHour,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        velocityAlerts: j['velocityAlerts'] as bool? ?? true,
        morningDigest: j['morningDigest'] as bool? ?? true,
        watchlistAlerts: j['watchlistAlerts'] as bool? ?? true,
        digestHour: j['digestHour'] as int? ?? 8,
      );
}

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  static const _key = 'unitrend_notif_prefs_v1';

  NotificationPrefsNotifier() : super(const NotificationPrefs()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      state = NotificationPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> setVelocityAlerts(bool v) async {
    state = state.copyWith(velocityAlerts: v);
    await _save();
  }

  Future<void> setMorningDigest(bool v) async {
    state = state.copyWith(morningDigest: v);
    await _save();
  }

  Future<void> setWatchlistAlerts(bool v) async {
    state = state.copyWith(watchlistAlerts: v);
    await _save();
  }

  Future<void> setDigestHour(int hour) async {
    state = state.copyWith(digestHour: hour.clamp(0, 23));
    await _save();
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  (_) => NotificationPrefsNotifier(),
);
