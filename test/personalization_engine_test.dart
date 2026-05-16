import 'package:flutter_test/flutter_test.dart';
import 'package:unitrendclaude/models/feedback_entry.dart';
import 'package:unitrendclaude/models/trend_item.dart';
import 'package:unitrendclaude/services/personalization_engine.dart';

void main() {
  group('PersonalizationEngine', () {
    final engine = PersonalizationEngine();

    TrendItem buildItem({
      required String id,
      required String title,
      required TrendSource source,
      double normalizedScore = 50,
      List<String> tags = const [],
      String? clusterId,
    }) {
      return TrendItem(
        id: id,
        title: title,
        url: 'https://example.com/$id',
        source: source,
        publishedAt: DateTime(2026, 1, 1),
        normalizedScore: normalizedScore,
        tags: tags,
        clusterId: clusterId,
      );
    }

    test('boosts items that match positive topic signals', () {
      final liked = buildItem(
        id: 'liked',
        title: 'OpenAI launches GPT coding update',
        source: TrendSource.github,
        tags: const ['openai', 'gpt', 'coding'],
        clusterId: 'ai',
      );
      final candidate = buildItem(
        id: 'candidate',
        title: 'GPT coding tools improve developer workflows',
        source: TrendSource.github,
        normalizedScore: 40,
        tags: const ['gpt', 'coding', 'developer'],
        clusterId: 'ai',
      );
      final control = buildItem(
        id: 'control',
        title: 'Celebrity fashion roundup',
        source: TrendSource.news,
        normalizedScore: 40,
        tags: const ['fashion', 'celebrity'],
      );

      final profile = engine.buildProfile(
        feedbackEntries: [
          FeedbackEntry.fromTrendItem(liked, isPositive: true),
        ],
        bookmarks: const [],
        searchQueries: const [],
      );

      final reranked = engine.rerank([control, candidate], profile);
      expect(reranked.first.id, 'candidate');
      expect(
        reranked.first.normalizedScore,
        greaterThan(control.normalizedScore),
      );
    });

    test('strongly suppresses explicitly disliked items', () {
      final disliked = buildItem(
        id: 'disliked',
        title: 'Crypto meme coin rally',
        source: TrendSource.news,
        normalizedScore: 70,
        tags: const ['crypto', 'meme'],
      );
      final neutral = buildItem(
        id: 'neutral',
        title: 'Flutter desktop release notes',
        source: TrendSource.github,
        normalizedScore: 55,
        tags: const ['flutter', 'desktop'],
      );

      final profile = engine.buildProfile(
        feedbackEntries: [
          FeedbackEntry.fromTrendItem(disliked, isPositive: false),
        ],
        bookmarks: const [],
        searchQueries: const [],
      );

      final reranked = engine.rerank([disliked, neutral], profile);
      final suppressed = reranked.firstWhere((item) => item.id == 'disliked');
      expect(suppressed.normalizedScore, lessThan(10));
    });
  });
}
