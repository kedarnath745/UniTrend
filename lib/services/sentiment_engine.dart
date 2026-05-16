import '../models/trend_item.dart';

/// Lightweight keyword-based sentiment detector.
/// Analyses title + description tokens against curated word sets and returns
/// the dominant sentiment. Reddit items get an upweighted controversial score
/// because thread titles frequently signal debate/conflict.
class SentimentEngine {
  // ── Keyword sets ────────────────────────────────────────────────────────────

  static const _positive = {
    // Achievement / success
    'breakthrough', 'success', 'successful', 'solved', 'win', 'wins', 'winner',
    'won', 'milestone', 'record', 'achievement', 'celebrate', 'celebration',
    'award', 'awarded', 'approved', 'approve',
    // Growth / momentum
    'growth', 'grows', 'surge', 'surges', 'surging', 'rally', 'rallies',
    'soars', 'soaring', 'rises', 'rising', 'boosts', 'boosting', 'thriving',
    'profits', 'profit', 'gains', 'gain',
    // Sentiment / excitement
    'amazing', 'love', 'best', 'hyped', 'hype', 'impressive', 'incredible',
    'excellent', 'outstanding', 'remarkable', 'innovative', 'revolutionary',
    'historic', 'launch', 'launched', 'release', 'released',
  };

  static const _critical = {
    // Failure / malfunction
    'fail', 'fails', 'failed', 'failure', 'broken', 'breaks', 'broke',
    'crash', 'crashes', 'crashed', 'outage', 'down', 'offline', 'bug', 'bugs',
    'error', 'errors', 'glitch', 'vulnerability', 'exploit', 'breach',
    // Negative action
    'scam', 'fraud', 'fake', 'misleading', 'dangerous', 'risky', 'risk',
    'threat', 'warned', 'warning', 'worst', 'bad',
    'shutdown', 'shuts', 'quit', 'quitting', 'resign', 'resigns', 'resigned',
    // Harm / incident
    'hack', 'hacked', 'hacking', 'attack', 'attacked', 'stolen', 'leak',
    'leaked', 'exposed', 'disaster', 'collapse', 'collapses', 'dead', 'death',
    'killed', 'arrested', 'investigation', 'layoffs', 'fired', 'banned',
  };

  static const _controversial = {
    // Conflict signals
    'vs', 'versus', 'debate', 'debates', 'debated', 'debating',
    'dispute', 'disputes', 'disputed', 'argument', 'arguments', 'clash',
    'clashes', 'clashed', 'fight', 'fights', 'fighting', 'conflict',
    'conflicts', 'controversy', 'controversial',
    // Legal / political
    'lawsuit', 'lawsuits', 'sued', 'suing', 'ban', 'bans', 'banned',
    'banning', 'protest', 'protests', 'protesting', 'oppose', 'opposition',
    'against', 'accused', 'accuses', 'allegation', 'allegations',
    'censored', 'censorship', 'misinformation', 'propaganda',
    // Criticism / backlash
    'backlash', 'criticized', 'criticizes', 'criticism', 'divided', 'split',
    'opinion', 'opinions', 'polarizing', 'outrage', 'outrages',
    'defends', 'defend', 'rejects', 'reject', 'refuses', 'refuse',
  };

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Detects sentiment for a single [item].
  /// Reddit items get a 1.5× boost on the controversial score.
  static TrendSentiment detect(TrendItem item) {
    final text = _buildText(item);
    final tokens = _tokenize(text);

    int positiveHits = _countHits(tokens, _positive);
    int criticalHits = _countHits(tokens, _critical);
    int controversialHits = _countHits(tokens, _controversial);

    // Reddit threads amplify controversy signals
    if (item.source == TrendSource.reddit) {
      controversialHits = (controversialHits * 1.5).round();
    }

    final maxHits = [positiveHits, criticalHits, controversialHits]
        .fold(0, (a, b) => a > b ? a : b);

    if (maxHits == 0) return TrendSentiment.neutral;

    // Tie-break: controversial > critical > positive (more informative to surface)
    if (controversialHits == maxHits) return TrendSentiment.controversial;
    if (criticalHits == maxHits) return TrendSentiment.critical;
    return TrendSentiment.positive;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _buildText(TrendItem item) {
    final buf = StringBuffer(item.title);
    if (item.description != null && item.description!.isNotEmpty) {
      buf.write(' ');
      // Limit description to first 400 chars to keep it fast
      final desc = item.description!;
      buf.write(desc.length > 400 ? desc.substring(0, 400) : desc);
    }
    // Tags are already derived from the title — no need to re-add them
    return buf.toString();
  }

  static List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1)
      .toList();

  static int _countHits(List<String> tokens, Set<String> keywords) {
    int count = 0;
    for (final token in tokens) {
      if (keywords.contains(token)) count++;
    }
    return count;
  }
}
