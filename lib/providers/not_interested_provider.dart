import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotInterestedNotifier extends StateNotifier<Set<String>> {
  static const _key = 'unitrend_not_interested_v1';
  static const _cap = 500;

  NotInterestedNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = Set.unmodifiable(list);
  }

  Future<void> dismiss(String id) async {
    final next = {...state, id};
    final capped = next.length > _cap
        ? Set.unmodifiable(next.toList().sublist(next.length - _cap))
        : Set.unmodifiable(next);
    state = capped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  Future<void> clear() async {
    state = const {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final notInterestedProvider =
    StateNotifierProvider<NotInterestedNotifier, Set<String>>(
  (_) => NotInterestedNotifier(),
);
