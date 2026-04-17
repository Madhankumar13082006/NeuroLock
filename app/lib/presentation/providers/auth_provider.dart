import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
      if (_svc.currentUser != null) {
        state = const AuthState(status: AuthStatus.success);
        return true;
      }
      // Firestore type mismatches can happen - show generic error
      state = const AuthState(
        status: AuthStatus.error,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _svc.loginWithGoogle();
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      if (_svc.currentUser != null) {
        state = const AuthState(status: AuthStatus.success);
        return true;
      }
      state = AuthState(status: AuthStatus.error, error: _msg(e.code));
      return false;
    } on PlatformException catch (e) {
      if (_svc.currentUser != null) {
        state = const AuthState(status: AuthStatus.success);
        return true;
      }
      state = AuthState(
        status: AuthStatus.error,
        error: _msg(e.code),
      );
      return false;
    } catch (e) {
      if (_svc.currentUser != null) {
        state = const AuthState(status: AuthStatus.success);
        return true;
      }
      state = const AuthState(
        status: AuthStatus.error,
        error: 'Google sign-in failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register(String email, String pass, String name) async {
    state = const AuthState(status: AuthStatus.loading);
    final normalizedEmail = email.trim();
    try {
      await _svc.register(normalizedEmail, pass, name.trim());
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      if (await _treatAsRegisterSuccessIfCreated(normalizedEmail)) {
        return true;
      }
      state = AuthState(status: AuthStatus.error, error: _msg(e.code));
      return false;
    } on FirebaseException catch (e) {
      if (await _treatAsRegisterSuccessIfCreated(normalizedEmail)) {
        return true;
      }
      final code = _extractCode(e.code, e.message);
      state = AuthState(status: AuthStatus.error, error: _msg(code));
      return false;
    } on PlatformException catch (e) {
      if (await _treatAsRegisterSuccessIfCreated(normalizedEmail)) {
        return true;
      }
      final code = _extractCode(e.code, e.message);
      state = AuthState(status: AuthStatus.error, error: _msg(code));
      return false;
    } catch (e) {
      if (await _treatAsRegisterSuccessIfCreated(normalizedEmail)) {
        return true;
      }
      final code = _extractCode(null, e.toString());
      if (code == 'email-already-in-use') {
        state = AuthState(status: AuthStatus.error, error: _msg(code));
        return false;
      }
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
        return 'Email already registered. Please sign in instead.';
      case 'weak-password':
        return 'Password too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'Network issue detected. Please check internet and retry.';
      case 'email-not-verified':
        return 'Please verify your email from inbox, then sign in.';
      case 'recaptcha-error':
        return 'Temporary auth issue. Please wait and retry.';
      case 'aborted-by-user':
      case 'sign_in_canceled':
        return 'Google sign-in was cancelled.';
      case 'google-id-token-missing':
        return 'Google token missing. Check Firebase OAuth setup.';
      case 'sign_in_failed':
      case 'DEVELOPER_ERROR':
        return 'Google sign-in configuration error. Add SHA-1/SHA-256 in Firebase for this app.';
      case 'internal-error':
        return 'Authentication service is temporarily unavailable. Please try again.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  String _extractCode(String? rawCode, String? rawMessage) {
    final code = (rawCode ?? '').toLowerCase();
    final message = (rawMessage ?? '').toLowerCase();

    if (code.contains('email-already-in-use') ||
        message.contains('email-already-in-use') ||
        message.contains('already in use') ||
        message.contains('already registered')) {
      return 'email-already-in-use';
    }
    if (code.contains('invalid-email') || message.contains('invalid email')) {
      return 'invalid-email';
    }
    if (code.contains('weak-password') || message.contains('weak-password')) {
      return 'weak-password';
    }
    if (code.contains('network-request-failed') ||
        message.contains('network')) {
      return 'network-request-failed';
    }
    return rawCode ?? 'unknown';
  }

  Future<bool> _emailHasAnySignInMethod(String email) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _treatAsRegisterSuccessIfCreated(String email) async {
    final current = _svc.currentUser;
    if (current != null && (current.email ?? '').toLowerCase() == email.toLowerCase()) {
      state = const AuthState(status: AuthStatus.success);
      try {
        await _svc.logout();
      } catch (_) {}
      return true;
    }

    final accountExists = await _emailHasAnySignInMethod(email);
    if (accountExists) {
      state = const AuthState(status: AuthStatus.success);
      return true;
    }

    return false;
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(firebaseServiceProvider)),
);
