import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class PersonalizationPrefs {
  /// Master on/off switch. When false the feed is pure trending order.
  final bool enabled;

  /// Topics the user explicitly added — e.g. "AI", "crypto", "basketball".
  /// These receive a strong positive boost in the reranker.
  final List<String> interests;

  const PersonalizationPrefs({
    this.enabled = true,
    this.interests = const [],
  });

  PersonalizationPrefs copyWith({
    bool? enabled,
    List<String>? interests,
  }) =>
      PersonalizationPrefs(
        enabled: enabled ?? this.enabled,
        interests: interests ?? this.interests,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'interests': interests,
      };

  factory PersonalizationPrefs.fromJson(Map<String, dynamic> j) =>
      PersonalizationPrefs(
        enabled: (j['enabled'] as bool?) ?? true,
        interests: (j['interests'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PersonalizationPrefsNotifier
    extends StateNotifier<PersonalizationPrefs> {
  static const _key = 'unitrend_personalization_prefs_v1';

  PersonalizationPrefsNotifier() : super(const PersonalizationPrefs()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      state = PersonalizationPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
    _save();
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _save();
  }

  void addInterest(String topic) {
    final t = topic.trim().toLowerCase();
    if (t.isEmpty || state.interests.contains(t)) return;
    state = state.copyWith(interests: [...state.interests, t]);
    _save();
  }

  void removeInterest(String topic) {
    state = state.copyWith(
      interests: state.interests.where((i) => i != topic).toList(),
    );
    _save();
  }

  void clearInterests() {
    state = state.copyWith(interests: []);
    _save();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final personalizationPrefsProvider = StateNotifierProvider<
    PersonalizationPrefsNotifier, PersonalizationPrefs>(
  (_) => PersonalizationPrefsNotifier(),
);
