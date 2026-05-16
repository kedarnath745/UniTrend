import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_entry.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> updateProfilePic(String uid, String url) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'profilePicUrl': url}, SetOptions(merge: true));
  }

  Future<void> addToSearchHistory(String uid, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    final data = doc.data() ?? {};

    final raw = List<dynamic>.from(data['searchHistory'] as List? ?? []);
    raw.removeWhere((entry) {
      if (entry is Map) return entry['query'] == trimmed;
      return entry.toString() == trimmed;
    });
    raw.add({'query': trimmed, 'timestamp': Timestamp.now()});

    final capped = raw.length > 20 ? raw.sublist(raw.length - 20) : raw;
    final recent = capped.reversed
        .map((entry) => entry is Map ? entry['query'] as String : entry.toString())
        .take(5)
        .toList();

    await docRef.set(
      {'searchHistory': capped, 'recentSearches': recent},
      SetOptions(merge: true),
    );
  }

  Future<List<Map<String, dynamic>>> getSearchHistory(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = List<dynamic>.from(doc.data()!['searchHistory'] as List? ?? []);
    return raw.reversed
        .take(20)
        .map((entry) => entry is Map<String, dynamic>
            ? entry
            : <String, dynamic>{'query': entry.toString()})
        .toList();
  }

  Future<void> removeFromSearchHistory(String uid, String query) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) return;

    final raw = List<dynamic>.from(doc.data()!['searchHistory'] as List? ?? []);
    raw.removeWhere((entry) {
      if (entry is Map) return entry['query'] == query;
      return entry.toString() == query;
    });

    final recent = raw.reversed
        .map((entry) => entry is Map ? entry['query'] as String : entry.toString())
        .take(5)
        .toList();

    await docRef.set(
      {'searchHistory': raw, 'recentSearches': recent},
      SetOptions(merge: true),
    );
  }

  Future<void> clearSearchHistory(String uid) async {
    await _db.collection('users').doc(uid).set(
      {'searchHistory': [], 'recentSearches': []},
      SetOptions(merge: true),
    );
  }

  Future<void> saveUserPreferences(
    String uid,
    Map<String, dynamic> preferences,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'preferences': preferences}, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getUserPreferences(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return {};
    return Map<String, dynamic>.from(doc.data()!['preferences'] as Map? ?? {});
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = List<dynamic>.from(doc.data()!['bookmarks'] as List? ?? []);
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<void> addBookmark(String uid, Map<String, dynamic> itemMap) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    final raw = List<dynamic>.from((doc.data() ?? {})['bookmarks'] as List? ?? []);
    raw.removeWhere((entry) => entry is Map && entry['id'] == itemMap['id']);
    raw.insert(0, itemMap);
    await docRef.set({'bookmarks': raw}, SetOptions(merge: true));
  }

  Future<void> removeBookmark(String uid, String itemId) async {
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    final raw = List<dynamic>.from((doc.data() ?? {})['bookmarks'] as List? ?? []);
    raw.removeWhere((entry) => entry is Map && entry['id'] == itemId);
    await docRef.set({'bookmarks': raw}, SetOptions(merge: true));
  }

  Future<void> clearBookmarks(String uid) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'bookmarks': []}, SetOptions(merge: true));
  }

  Future<void> recordFeedback(String uid, FeedbackEntry entry) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .doc(entry.itemId)
        .set(entry.toMap());
  }

  Future<void> removeFeedback(String uid, String itemId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .doc(itemId)
        .delete();
  }

  Future<Map<String, FeedbackEntry>> getFeedbacks(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .get();
    return {
      for (final doc in snap.docs)
        doc.id: FeedbackEntry.fromMap({
          'itemId': doc.id,
          ...doc.data(),
        }),
    };
  }
}
