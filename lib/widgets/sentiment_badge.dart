import 'package:flutter/material.dart';
import '../models/trend_item.dart';

/// A compact sentiment indicator shown next to the source chip on a TrendCard.
/// Neutral items render nothing — call-site guards with `sentiment != neutral`.
class SentimentBadge extends StatelessWidget {
  final TrendSentiment sentiment;
  /// When true, renders a smaller dot-only version without the icon.
  final bool compact;

  const SentimentBadge({super.key, required this.sentiment, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _config(sentiment);

    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }

    return Tooltip(
      message: label,
      preferBelow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Icon(icon, size: 11, color: color),
        ],
      ),
    );
  }

  static (Color, IconData, String) _config(TrendSentiment s) {
    switch (s) {
      case TrendSentiment.positive:
        return (
          const Color(0xFF22C55E), // green-500
          Icons.add_circle_outline,
          'Positive vibe',
        );
      case TrendSentiment.critical:
        return (
          const Color(0xFFEF4444), // red-500
          Icons.error_outline,
          'Critical / Warning',
        );
      case TrendSentiment.controversial:
        return (
          const Color(0xFFF59E0B), // amber-500
          Icons.swap_horiz,
          'High Controversy',
        );
      case TrendSentiment.neutral:
        return (Colors.transparent, Icons.circle, '');
    }
  }
}
