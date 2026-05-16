import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? phone;
  final String displayName;
  final String? profilePicUrl;
  final DateTime? dateOfBirth;
  final List<String> searchHistory;
  final List<String> recentSearches;
  final DateTime createdAt;
  final DateTime lastLogin;
  final Map<String, dynamic> preferences;

  const UserModel({
    required this.uid,
    this.email,
    this.phone,
    required this.displayName,
    this.profilePicUrl,
    this.dateOfBirth,
    this.searchHistory = const [],
    this.recentSearches = const [],
    required this.createdAt,
    required this.lastLogin,
    this.preferences = const {},
  });

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      a--;
    }
    return a;
  }

  bool get isMinor => age > 0 && age < 18;

  UserModel copyWith({
    String? displayName,
    String? profilePicUrl,
    DateTime? dateOfBirth,
    List<String>? searchHistory,
    List<String>? recentSearches,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      phone: phone,
      displayName: displayName ?? this.displayName,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      searchHistory: searchHistory ?? this.searchHistory,
      recentSearches: recentSearches ?? this.recentSearches,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'phone': phone,
        'displayName': displayName,
        'profilePicUrl': profilePicUrl,
        'dateOfBirth':
            dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'searchHistory': searchHistory,
        'recentSearches': recentSearches,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastLogin': Timestamp.fromDate(lastLogin),
        'preferences': preferences,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      displayName: map['displayName'] as String? ?? 'User',
      profilePicUrl: map['profilePicUrl'] as String?,
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      searchHistory: (map['searchHistory'] as List? ?? [])
          .map((e) => e is Map ? (e['query'] as String? ?? '') : e.toString())
          .where((s) => s.isNotEmpty)
          .toList(),
      recentSearches: (map['recentSearches'] as List? ?? [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? (map['lastLogin'] as Timestamp).toDate()
          : DateTime.now(),
      preferences:
          Map<String, dynamic>.from(map['preferences'] as Map? ?? {}),
    );
  }
}
