import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_entry.dart';
import '../models/trend_item.dart';
import 'user_provider.dart';

class _FeedbackNotifier extends StateNotifier<Map<String, FeedbackEntry>> {
  _FeedbackNotifier() : super({});

  void load(Map<String, FeedbackEntry> data) => state = data;

  FeedbackEntry? record(TrendItem item, bool isPositive) {
    final existing = state[item.id];
    if (existing?.isPositive == isPositive) {
      state = Map.from(state)..remove(item.id);
      return null;
    }

    final entry = FeedbackEntry.fromTrendItem(item, isPositive: isPositive);
    state = {...state, item.id: entry};
    return entry;
  }
}

final feedbackProvider =
    StateNotifierProvider<_FeedbackNotifier, Map<String, FeedbackEntry>>(
  (_) => _FeedbackNotifier(),
);

final feedbackLoaderProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  Map<String, FeedbackEntry> data;

  if (user != null) {
    data = await ref.read(firestoreServiceProvider).getFeedbacks(user.uid);
  } else {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('guest_feedback');
    if (raw == null) {
      data = {};
    } else {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        data = decoded.map((key, value) => MapEntry(
              key,
              FeedbackEntry.fromMap({
                'itemId': key,
                if (value is bool)
                  'isPositive': value
                else
                  ...(value as Map<String, dynamic>),
              }),
            ));
      } catch (_) {
        data = {};
      }
    }
  }

  ref.read(feedbackProvider.notifier).load(data);
});

Future<void> recordFeedback(
  WidgetRef ref,
  TrendItem item,
  bool isPositive,
) async {
  final entry = ref.read(feedbackProvider.notifier).record(item, isPositive);
  final user = ref.read(currentUserProvider).valueOrNull ??
      await ref.read(currentUserProvider.future).catchError((_) => null);

  if (user != null) {
    if (entry == null) {
      await ref.read(firestoreServiceProvider).removeFeedback(user.uid, item.id);
    } else {
      await ref.read(firestoreServiceProvider).recordFeedback(user.uid, entry);
    }
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final current = ref.read(feedbackProvider);
  await prefs.setString(
    'guest_feedback',
    jsonEncode({
      for (final entry in current.entries) entry.key: entry.value.toMap(),
    }),
  );
}
