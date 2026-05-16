import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedDashboardsNotifier extends StateNotifier<List<String>> {
  static const _prefsKey = 'saved_dashboards';

  SavedDashboardsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? [];
  }

  Future<void> pin(String query) async {
    final q = query.trim();
    if (q.isEmpty || state.contains(q)) return;
    state = [q, ...state]; // newest pinned first
    await _save();
  }

  Future<void> unpin(String query) async {
    state = state.where((q) => q != query.trim()).toList();
    await _save();
  }

  bool isPinned(String query) => state.contains(query.trim());

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }
}

final savedDashboardsProvider =
    StateNotifierProvider<SavedDashboardsNotifier, List<String>>(
  (_) => SavedDashboardsNotifier(),
);
