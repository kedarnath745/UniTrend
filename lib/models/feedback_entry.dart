import 'package:cloud_firestore/cloud_firestore.dart';
import 'trend_item.dart';

class FeedbackEntry {
  final String itemId;
  final bool isPositive;
  final TrendSource source;
  final List<String> tags;
  final String? clusterId;
  final String title;
  final String? sourceName;
  final String? author;
  final DateTime recordedAt;

  const FeedbackEntry({
    required this.itemId,
    required this.isPositive,
    required this.source,
    required this.tags,
    required this.title,
    required this.recordedAt,
    this.clusterId,
    this.sourceName,
    this.author,
  });

  factory FeedbackEntry.fromTrendItem(
    TrendItem item, {
    required bool isPositive,
    DateTime? recordedAt,
  }) {
    return FeedbackEntry(
      itemId: item.id,
      isPositive: isPositive,
      source: item.source,
      tags: item.tags,
      clusterId: item.clusterId,
      title: item.title,
      sourceName: item.sourceName,
      author: item.author,
      recordedAt: recordedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'isPositive': isPositive,
        'source': source.name,
        'tags': tags,
        'clusterId': clusterId,
        'title': title,
        'sourceName': sourceName,
        'author': author,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    final itemId = (map['itemId'] ?? map['id'] ?? '') as String;
    final recordedAtValue = map['recordedAt'];
    return FeedbackEntry(
      itemId: itemId,
      isPositive: map['isPositive'] as bool? ?? true,
      source: TrendSource.values.firstWhere(
        (value) => value.name == map['source'],
        orElse: () => TrendSource.news,
      ),
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      clusterId: map['clusterId'] as String?,
      title: map['title'] as String? ?? '',
      sourceName: map['sourceName'] as String?,
      author: map['author'] as String?,
      recordedAt: switch (recordedAtValue) {
        DateTime value => value,
        Timestamp value => value.toDate(),
        String value => DateTime.tryParse(value) ?? DateTime.now(),
        _ => DateTime.now(),
      },
    );
  }
}
