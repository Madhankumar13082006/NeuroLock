import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Store user profile in Firestore
      await _db.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': cred.user!.uid,
      });
      return cred;
    } on FirebaseAuthException catch (e) {
      // reCAPTCHA not configured - this is expected in dev
      // Just re-throw with a more user-friendly message
      if (e.code.contains('configuration') ||
          e.code.contains('CONFIGURATION_NOT_FOUND') ||
          e.message?.contains('reCAPTCHA') == true) {
        // Re-throw but make sure error is mapped in provider
        throw FirebaseAuthException(
          code: 'recaptcha-error',
          message: 'Temporary service issue. Please try again in 30 seconds.',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> login(String email, String password) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() => _auth.signOut();
}
