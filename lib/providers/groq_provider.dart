import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trend_item.dart';
import '../services/groq_service.dart';

// ── Trend Digest ──────────────────────────────────────────────────────────────

enum DigestPeriod { hourly, daily, weekly }

extension DigestPeriodX on DigestPeriod {
  String get label {
    switch (this) {
      case DigestPeriod.hourly: return '1H';
      case DigestPeriod.daily:  return '24H';
      case DigestPeriod.weekly: return '7D';
    }
  }

  String get promptLabel {
    switch (this) {
      case DigestPeriod.hourly: return 'the last hour';
      case DigestPeriod.daily:  return 'today';
      case DigestPeriod.weekly: return 'this week';
    }
  }

  Duration get duration {
    switch (this) {
      case DigestPeriod.hourly: return const Duration(hours: 1);
      case DigestPeriod.daily:  return const Duration(hours: 24);
      case DigestPeriod.weekly: return const Duration(days: 7);
    }
  }
}

class DigestState {
  final DigestPeriod period;
  final AsyncValue<String> value;
  const DigestState({
    this.period = DigestPeriod.daily,
    this.value = const AsyncValue.data(''),
  });
  DigestState copyWith({DigestPeriod? period, AsyncValue<String>? value}) =>
      DigestState(period: period ?? this.period, value: value ?? this.value);
}

class TrendDigestNotifier extends StateNotifier<DigestState> {
  final GroqService _service;
  TrendDigestNotifier(this._service) : super(const DigestState());

  Future<void> generate(List<TrendItem> allItems, DigestPeriod period) async {
    state = state.copyWith(period: period, value: const AsyncValue.loading());

    final cutoff = DateTime.now().subtract(period.duration);
    final filtered = allItems
        .where((i) => i.publishedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.normalizedScore.compareTo(a.normalizedScore));

    // Fall back to top items from full feed if nothing in the window
    final items = filtered.isNotEmpty ? filtered : allItems.take(15).toList();

    try {
      final digest = await _service.summarizeTrends(items, period.promptLabel);
      state = state.copyWith(value: AsyncValue.data(digest));
    } catch (e, st) {
      state = state.copyWith(value: AsyncValue.error(e, st));
    }
  }

  void setPeriod(DigestPeriod period) {
    state = state.copyWith(period: period, value: const AsyncValue.data(''));
  }
}

final trendDigestProvider =
    StateNotifierProvider<TrendDigestNotifier, DigestState>(
  (ref) => TrendDigestNotifier(ref.watch(groqServiceProvider)),
);

final groqServiceProvider = Provider((_) => GroqService());

/// Per-item AI summaries. Absent = not requested. Loading/Data/Error = in-flight or done.
class SummaryNotifier
    extends StateNotifier<Map<String, AsyncValue<String>>> {
  final GroqService _service;
  SummaryNotifier(this._service) : super({});

  Future<void> fetch(TrendItem item) async {
    final existing = state[item.id];
    if (existing is AsyncLoading || existing is AsyncData) return;

    state = {...state, item.id: const AsyncValue.loading()};
    try {
      final summary = await _service.summarize(item);
      state = {...state, item.id: AsyncValue.data(summary)};
    } catch (e, st) {
      state = {...state, item.id: AsyncValue.error(e, st)};
    }
  }

  void retry(TrendItem item) {
    state = Map.from(state)..remove(item.id);
  }
}

final summaryNotifierProvider =
    StateNotifierProvider<SummaryNotifier, Map<String, AsyncValue<String>>>(
  (ref) => SummaryNotifier(ref.watch(groqServiceProvider)),
);

// ── Source Comparison (per cluster) ──────────────────────────────────────────

/// Per-cluster source comparison. Key = clusterId. Fetched on demand.
class SourceComparisonNotifier
    extends StateNotifier<Map<String, AsyncValue<String>>> {
  final GroqService _service;
  SourceComparisonNotifier(this._service) : super({});

  Future<void> fetch(
      String clusterId, List<TrendItem> items, String topic) async {
    final existing = state[clusterId];
    if (existing is AsyncLoading || existing is AsyncData) return;

    state = {...state, clusterId: const AsyncValue.loading()};
    try {
      final result = await _service.compareSourcePerspectives(items, topic);
      state = {...state, clusterId: AsyncValue.data(result)};
    } catch (e, st) {
      state = {...state, clusterId: AsyncValue.error(e, st)};
    }
  }

  void retry(String clusterId) {
    state = Map.from(state)..remove(clusterId);
  }
}

final sourceComparisonProvider = StateNotifierProvider<SourceComparisonNotifier,
    Map<String, AsyncValue<String>>>(
  (ref) => SourceComparisonNotifier(ref.watch(groqServiceProvider)),
);

// ── Cluster Chat ──────────────────────────────────────────────────────────────

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isLoading;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
  });
}
