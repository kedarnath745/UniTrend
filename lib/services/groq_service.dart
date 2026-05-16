import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/trend_item.dart';

class GroqService {
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  String? get _apiKey => dotenv.env['GROQ_API_KEY'];

  Future<String> summarize(TrendItem item) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a senior tech and culture analyst writing for a smart general audience. '
                    'Given a trending item, write 4–5 sentences covering: '
                    '(1) what it is and the core context, '
                    '(2) why it is trending right now and what triggered it, '
                    '(3) who it impacts and how, '
                    '(4) what it signals about a broader trend or shift. '
                    'Be specific, insightful, and direct. No bullet points, no markdown, no filler phrases like "In summary" or "It\'s worth noting".',
              },
              {
                'role': 'user',
                'content': _buildPrompt(item),
              },
            ],
            'max_tokens': 300,
            'temperature': 0.5,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }

  String _buildPrompt(TrendItem item) {
    final buf = StringBuffer('Title: ${item.title}\n');
    buf.write('Source: ${item.sourceLabel}\n');
    if (item.trendingReason != null) buf.write('Context: ${item.trendingReason}\n');
    if (item.description != null && item.description!.trim().isNotEmpty) {
      final desc = item.description!.trim();
      buf.write('Description: ${desc.length > 600 ? '${desc.substring(0, 600)}…' : desc}\n');
    }
    if (item.tags.isNotEmpty) buf.write('Keywords: ${item.tags.join(', ')}\n');
    return buf.toString();
  }

  /// Explains how different platforms are framing the same cluster topic.
  /// [items] should contain items from at least 2 distinct sources.
  Future<String> compareSourcePerspectives(
    List<TrendItem> items,
    String topic,
  ) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }

    // Group titles by source label
    final bySource = <String, List<String>>{};
    for (final item in items) {
      bySource.putIfAbsent(item.sourceLabel, () => []).add(item.title);
    }

    if (bySource.length < 2) {
      throw Exception('Need at least 2 sources to compare perspectives');
    }

    final sourceLines = bySource.entries.map((e) {
      final titles = e.value.take(3).map((t) => '• $t').join('\n');
      return '${e.key}:\n$titles';
    }).join('\n\n');

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a media analyst who studies how different platforms frame the same topic. '
                    'Given headlines about the same topic from multiple platforms, write 4–5 sentences that: '
                    '(1) describe the distinct angle each platform takes, '
                    '(2) explain what each angle reveals about that platform\'s audience and incentives, '
                    '(3) identify which perspective is missing or underrepresented. '
                    'Be specific — name the framing differences. No bullet points, no headers, no filler.',
              },
              {
                'role': 'user',
                'content':
                    'Topic: #$topic\n\nHere is how each platform is covering it:\n\n$sourceLines\n\n'
                    'Compare the perspectives.',
              },
            ],
            'max_tokens': 350,
            'temperature': 0.5,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }

  /// Conversational researcher for a cluster topic.
  /// [history] alternates user/assistant pairs from earlier in the conversation.
  Future<String> chatWithCluster(
    List<TrendItem> items,
    String userQuery, {
    List<Map<String, String>> history = const [],
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }

    final context = items.take(12).toList().asMap().entries.map((e) {
      final item = e.value;
      final desc = item.description?.trim() ?? '';
      final snippet = desc.isNotEmpty
          ? ': ${desc.substring(0, desc.length.clamp(0, 200))}'
          : '';
      return '${e.key + 1}. [${item.sourceLabel}] ${item.title}$snippet';
    }).join('\n');

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'You are an expert trend analyst and researcher. You have been given '
            'trending stories about a specific topic. Answer the user\'s questions '
            'concisely and insightfully based on the provided stories. '
            'Be direct, specific, and conversational. Max 3–4 sentences per reply. '
            'No bullet lists unless explicitly requested.\n\n'
            'TRENDING STORIES CONTEXT:\n$context',
      },
      ...history,
      {'role': 'user', 'content': userQuery},
    ];

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'max_tokens': 250,
            'temperature': 0.6,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }

  /// Generates a 1–2 sentence AI blurb describing why a topic is breaking out.
  /// Used by the velocity / breakout notification.
  Future<String> generateBreakoutBlurb(String topic, int scoreDelta) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You write breaking trend alerts for a smart news app. '
                    'Given a topic that just spiked in score, produce a SINGLE '
                    'notification blurb of 1–2 sentences (max 35 words). '
                    'Explain plausibly what is driving the breakout right now — '
                    'what happened, who is involved, and why it matters. '
                    'Be specific and confident. No hashtags, no emojis, no filler '
                    'phrases like "It seems" or "Reports suggest".',
              },
              {
                'role': 'user',
                'content':
                    'Topic: $topic\nScore jump: +$scoreDelta points in the last day.\n'
                    'Write the breakout blurb.',
              },
            ],
            'max_tokens': 120,
            'temperature': 0.6,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }

  /// Generates a 3-bullet morning briefing from a numbered list of headlines.
  /// Used by the background morning digest task.
  Future<String> generateMorningBriefing(String numberedHeadlines) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You write concise morning briefings for a smart news app. '
                    'Given a list of today\'s top headlines, produce exactly 3 bullet points. '
                    'Each bullet: one sentence, max 20 words, starts with a relevant emoji. '
                    'Cover the 3 most important distinct themes. No headers, no markdown beyond bullets.',
              },
              {
                'role': 'user',
                'content': "Today's top headlines:\n\n$numberedHeadlines\n\nWrite the 3-bullet briefing.",
              },
            ],
            'max_tokens': 150,
            'temperature': 0.5,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }

  /// Generates a trend digest paragraph for a list of trending items.
  /// [period] is a human label like "the last hour", "today", "this week".
  Future<String> summarizeTrends(
      List<TrendItem> items, String period) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY not set in .env');
    }
    if (items.isEmpty) throw Exception('No items to summarize');

    // Build a compact numbered list of top items for the prompt
    final lines = items.take(15).toList().asMap().entries.map((e) {
      final i = e.key + 1;
      final item = e.value;
      return '$i. [${item.sourceLabel}] ${item.title}';
    }).join('\n');

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a senior analyst writing a trend digest for a smart news app. '
                    'Given trending items from across tech, media, finance, and culture, write '
                    '5–7 sentences that: identify the 2–3 dominant themes, explain what is '
                    'driving each theme right now, highlight any surprising or counterintuitive '
                    'patterns, and end with one forward-looking observation about where things are headed. '
                    'Be specific — name the topics, people, or technologies involved. '
                    'No bullet points, no headers, no markdown, no generic filler.',
              },
              {
                'role': 'user',
                'content':
                    'Here are the top trending items from $period:\n\n$lines\n\n'
                    'Write a detailed digest explaining what is trending, why it matters, and what it signals.',
              },
            ],
            'max_tokens': 450,
            'temperature': 0.6,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['choices'] as List).first['message']['content'] as String)
        .trim();
  }
}
