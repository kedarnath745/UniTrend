import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// One score reading for a cluster at a point in time.
class ScoreSnapshot {
  final String clusterId;
  final String topic;
  final double score;
  final DateTime timestamp;

  const ScoreSnapshot({
    required this.clusterId,
    required this.topic,
    required this.score,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'c': clusterId,
        't': topic,
        's': score,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory ScoreSnapshot.fromJson(Map<String, dynamic> j) => ScoreSnapshot(
        clusterId: j['c'] as String,
        topic: j['t'] as String,
        score: (j['s'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
}

/// One aggregated data point per calendar day — highest score recorded that day.
class DailyScore {
  final DateTime day;   // midnight local time
  final double score;
  final bool isMeasured; // true = real snapshot; false = synthetic estimate

  const DailyScore({
    required this.day,
    required this.score,
    required this.isMeasured,
  });
}

/// Persists cluster score snapshots across sessions.
/// Powers the 7-day trend chart in ClusterDetailScreen.
class ScoreHistoryService {
  static const _key = 'unitrend_score_snapshots_v1';
  static const _maxAgeDays = 30;
  static const _maxEntries = 600;

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Records the current score for each cluster.
  /// Skips a cluster if a snapshot was already saved within the last 2 hours
  /// (prevents noisy duplicates from rapid feed refreshes).
  Future<void> snapshot(
      List<({String id, String topic, double score})> clusters) async {
    if (clusters.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = _load(prefs);

    final cutoff = DateTime.now().subtract(const Duration(days: _maxAgeDays));
    existing.removeWhere((s) => s.timestamp.isBefore(cutoff));

    final now = DateTime.now();
    final dedupeWindow = now.subtract(const Duration(hours: 2));

    for (final c in clusters) {
      // Skip if we already have a snapshot for this cluster in the last 2 hours
      final recentExists = existing.any((s) =>
          s.clusterId == c.id && s.timestamp.isAfter(dedupeWindow));
      if (recentExists) continue;

      existing.add(ScoreSnapshot(
        clusterId: c.id,
        topic: c.topic,
        score: c.score,
        timestamp: now,
      ));
    }

    final trimmed = existing.length > _maxEntries
        ? existing.sublist(existing.length - _maxEntries)
        : existing;

    await prefs.setString(
        _key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns raw snapshots for [clusterId] within [days] days, oldest first.
  Future<List<ScoreSnapshot>> getHistory(
    String clusterId, {
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _load(prefs);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return all
        .where((s) => s.clusterId == clusterId && s.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Returns one [DailyScore] per calendar day for the last [days] days.
  ///
  /// Days that have real snapshot data use the highest score recorded that day
  /// ([isMeasured] = true). Days without snapshots get [isMeasured] = false
  /// and a score of 0, letting callers overlay a synthetic estimate.
  Future<List<DailyScore>> getDailyAggregated(
    String clusterId, {
    int days = 7,
  }) async {
    final snapshots = await getHistory(clusterId, days: days);
    final today = _dayOnly(DateTime.now());

    // Group snapshots by calendar day → keep highest score
    final byDay = <DateTime, double>{};
    for (final s in snapshots) {
      final day = _dayOnly(s.timestamp);
      final prev = byDay[day];
      if (prev == null || s.score > prev) byDay[day] = s.score;
    }

    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      final score = byDay[day];
      return DailyScore(
        day: day,
        score: score ?? 0,
        isMeasured: score != null,
      );
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<ScoreSnapshot> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ScoreSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
