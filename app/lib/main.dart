import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'platform/method_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      print('Firebase init error: $e');
    }
  }

  // Don't require App Check for debug builds - it's blocking auth
  // Comment out if you need strict verification later
  // try {
  //   await FirebaseAppCheck.instance.activate(
  //     androidProvider: AndroidProvider.debug,
  //     appleProvider: AppleProvider.debug,
  //   );
  // } catch (e) {
  //   print('App Check init (non-blocking): $e');
  // }

  // Prefer a "no-login" UX by ensuring we always have a Firebase user.
  // If Anonymous auth isn't enabled in Firebase Console, this will fail
  // and the router will fall back to showing the login screen.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    print('Anonymous auth unavailable: $e');
  }

  // Allow Android accessibility service to navigate into Flutter.
  PlatformBridge.initNavigation((route) {
    // Use router from app.dart
    appRouterGo(route);
  });

  runApp(const ProviderScope(child: NokkonApp()));
}
