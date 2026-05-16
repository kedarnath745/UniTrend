import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final authStateProvider = StreamProvider<User?>((ref) {
  // Firebase has no Windows desktop support — emit null once (guest) and done
  if (!kIsWeb && Platform.isWindows) return Stream.value(null);
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return null;
  return ref.watch(firestoreServiceProvider).getUser(authState.uid);
});

final bookmarksProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getBookmarks(user.uid);
  }
  // Guest: load from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('guest_bookmarks');
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

final searchHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getSearchHistory(user.uid);
  }
  // Guest: load from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('guest_search_history');
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});
