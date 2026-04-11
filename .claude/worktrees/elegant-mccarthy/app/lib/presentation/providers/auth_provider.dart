import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authChanges;
});

enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  const AuthState({this.status = AuthStatus.idle, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseService _svc;
  AuthNotifier(this._svc) : super(const AuthState());

  Future<bool> login(String email, String pass) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _svc.login(email.trim(), pass);
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _msg(e.code));
      return false;
    } catch (e) {
      // Firestore type mismatches can happen - show generic error
      state = const AuthState(
        status: AuthStatus.error,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register(String email, String pass, String name) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _svc.register(email.trim(), pass, name.trim());
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _msg(e.code));
      return false;
    } catch (e) {
      state = const AuthState(
        status: AuthStatus.error,
        error: 'Failed to create account. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() => _svc.logout();

  String _msg(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'Email already registered. Please login.';
      case 'weak-password':
        return 'Password too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(firebaseServiceProvider)),
);
