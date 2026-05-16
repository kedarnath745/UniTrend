import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_state.dart';

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void togglePlatform(String platform) {
    final updated = Set<String>.from(state.enabledPlatforms);
    if (updated.contains(platform)) {
      if (updated.length > 1) updated.remove(platform);
    } else {
      updated.add(platform);
    }
    state = state.copyWith(enabledPlatforms: updated);
  }

  void setMinYoutubeViews(int value) =>
      state = state.copyWith(minYoutubeViews: value);

  void setMinRedditUpvotes(int value) =>
      state = state.copyWith(minRedditUpvotes: value);

  void setMinGithubStars(int value) =>
      state = state.copyWith(minGithubStars: value);

  void setGithubLanguages(Set<String> langs) =>
      state = state.copyWith(githubLanguages: langs);

  void setRedditSubreddits(List<String> subs) =>
      state = state.copyWith(redditSubreddits: subs);

  void toggleGithubLanguage(String lang) {
    final updated = Set<String>.from(state.githubLanguages);
    if (updated.contains(lang)) {
      updated.remove(lang);
    } else {
      updated.add(lang);
    }
    state = state.copyWith(githubLanguages: updated);
  }

  void setEnabledNewsSources(Set<String> sources) =>
      state = state.copyWith(enabledNewsSources: sources);

  void toggleNewsSource(String source) {
    final current = Set<String>.from(state.resolvedNewsSources);
    if (current.contains(source)) {
      if (current.length > 1) current.remove(source);
    } else {
      current.add(source);
    }
    // Store empty set when all sources are enabled (= default)
    final next = current.length == kAllNewsSources.length ? <String>{} : current;
    state = state.copyWith(enabledNewsSources: next);
  }

  void setDateFilter(DateFilter filter) =>
      state = state.copyWith(dateFilter: filter);

  void setSortOrder(SortOrder order) =>
      state = state.copyWith(sortOrder: order);

  void setSafeSearch(bool value) =>
      state = state.copyWith(safeSearch: value);

  void setRegion(FeedRegion region) =>
      state = state.copyWith(region: region);

  void setCategory(FeedCategory category) =>
      state = state.copyWith(category: category);

  void applyFromMap(Map<String, dynamic> map) =>
      state = FilterState.fromMap(map);

  void reset() => state = const FilterState();

  Future<void> saveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filters', jsonEncode(state.toMap()));
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('filters');
    if (json != null) {
      try {
        state = FilterState.fromMap(
            jsonDecode(json) as Map<String, dynamic>);
      } catch (_) {
        // ignore corrupt data
      }
    }
  }
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier();
});
