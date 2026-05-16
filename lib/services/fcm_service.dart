import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'background_service.dart';

/// Top-level FCM background handler — must be a top-level function.
/// Called when a data-only FCM message arrives while the app is
/// terminated or in the background.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  if (message.data['type'] == 'wakeup') {
    try {
      await runWatchlistCheck();
      await runVelocityCheck();
    } catch (_) {}
  } else if (message.data['type'] == 'morning_digest') {
    try {
      await runMorningDigest();
    } catch (_) {}
  }
}

class FcmService {
  static bool _initialized = false;

  /// Call once after Firebase.initializeApp(). No-ops on non-Android.
  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );

    // Save token to Firestore so the Cloud Function can reach this device.
    final token = await messaging.getToken();
    if (token != null) await _saveToken(token);

    // Refresh token when it rotates.
    messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground FCM messages (app open) — run checks silently,
    // local notifications are already fired by the existing watchlist logic.
    FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] == 'wakeup') {
        try {
          await runWatchlistCheck();
          await runVelocityCheck();
        } catch (_) {}
      } else if (message.data['type'] == 'morning_digest') {
        try {
          await runMorningDigest();
        } catch (_) {}
      }
    });
  }

  static Future<void> _saveToken(String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
