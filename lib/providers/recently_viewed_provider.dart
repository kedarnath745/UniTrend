import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trend_item.dart';

const _rvKey = 'unitrend_recently_viewed_v1';
const _rvMax = 50;


class RecentlyViewedItem {
  final String id;
  final String title;
  final String url;
  final String sourceLabel;
  final TrendSource source;
  final DateTime viewedAt;

  const RecentlyViewedItem({
    required this.id,
    required this.title,
    required this.url,
    required this.sourceLabel,
    required this.source,
    required this.viewedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'sl': sourceLabel,
    'src': source.index,
    'ts': viewedAt.millisecondsSinceEpoch,
  };

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> j) =>
      RecentlyViewedItem(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        sourceLabel: j['sl'] as String,
        source: TrendSource.values[(j['src'] as num).toInt()],
        viewedAt: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
}

class RecentlyViewedNotifier extends StateNotifier<List<RecentlyViewedItem>> {
  RecentlyViewedNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rvKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => RecentlyViewedItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> add(TrendItem item) async {
    final entry = RecentlyViewedItem(
      id: item.id,
      title: item.title,
      url: item.url,
      sourceLabel: item.sourceLabel,
      source: item.source,
      viewedAt: DateTime.now(),
    );
    final updated = [entry, ...state.where((e) => e.id != item.id)];
    state = updated.length > _rvMax ? updated.sublist(0, _rvMax) : updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _rvKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rvKey);
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedItem>>(
  (_) => RecentlyViewedNotifier(),
);
