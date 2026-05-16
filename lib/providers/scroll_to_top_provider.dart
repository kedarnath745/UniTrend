import 'package:flutter_riverpod/flutter_riverpod.dart';

// Each provider stores a counter that increments when the matching nav tab
// is double-tapped. Screens listen and animate their scroll to the top.
final radarScrollToTopProvider     = StateProvider<int>((ref) => 0);
final homeScrollToTopProvider      = StateProvider<int>((ref) => 0);
final trendingScrollToTopProvider  = StateProvider<int>((ref) => 0);
final bookmarksScrollToTopProvider = StateProvider<int>((ref) => 0);
