import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirestoreService _firestore = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  // ── Email / Password ───────────────────────────────────────────────────────

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    DateTime? dateOfBirth,
    File? profileImage,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user!;

    String? profilePicUrl;
    if (profileImage != null) {
      profilePicUrl =
          await _uploadProfileImage(firebaseUser.uid, profileImage);
    }

    await firebaseUser.updateDisplayName(displayName);
    if (profilePicUrl != null) {
      await firebaseUser.updatePhotoURL(profilePicUrl);
    }

    final user = UserModel(
      uid: firebaseUser.uid,
      email: email,
      displayName: displayName,
      profilePicUrl: profilePicUrl,
      dateOfBirth: dateOfBirth,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    await _firestore.saveUser(user);
    return user;
  }

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user!;
    final user = await _firestore.getUser(firebaseUser.uid);
    if (user != null) {
      await _firestore.saveUser(user.copyWith(lastLogin: DateTime.now()));
    }
    return user;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final firebaseUser = result.user!;

    var user = await _firestore.getUser(firebaseUser.uid);
    if (user == null) {
      user = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName ?? 'User',
        profilePicUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      await _firestore.saveUser(user);
    } else {
      await _firestore.saveUser(user.copyWith(lastLogin: DateTime.now()));
    }
    return user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  Future<void> sendOTP({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onVerificationCompleted,
    required void Function(FirebaseAuthException) onVerificationFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
    );
  }

  Future<UserModel?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final result = await _auth.signInWithCredential(credential);
    final firebaseUser = result.user!;

    var user = await _firestore.getUser(firebaseUser.uid);
    if (user == null) {
      user = UserModel(
        uid: firebaseUser.uid,
        phone: firebaseUser.phoneNumber,
        displayName: 'User',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      await _firestore.saveUser(user);
    } else {
      await _firestore.saveUser(user.copyWith(lastLogin: DateTime.now()));
    }
    return user;
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  Future<String> _uploadProfileImage(String uid, File image) async {
    final ref = _storage.ref().child('profile_pics/$uid.jpg');
    await ref.putFile(image);
    return ref.getDownloadURL();
  }

  Future<String> uploadProfileImage(String uid, File image) =>
      _uploadProfileImage(uid, image);

  // ── Anonymous / Guest ─────────────────────────────────────────────────────

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  // ── Delete Account ─────────────────────────────────────────────────────────

  Future<void> deleteAccount(String uid) async {
    // Delete Auth user first — if this fails, Firestore data is preserved.
    await _auth.currentUser?.delete();
    await _firestore.deleteUser(uid);
  }
}
