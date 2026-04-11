import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'platform/method_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait orientation — lock-screen layouts are
  // designed vertically and a rotated lock screen ruins the friction.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Always-on dark system UI overlays so the brand colors look right
  // edge-to-edge on Android.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('Firebase init error: $e');
    }
  }

  // Note: anonymous auth removed — we always require email/password
  // login per the Nokkon spec. The router redirects unauthenticated
  // users to /login.

  // Allow Android accessibility service to navigate into Flutter.
  PlatformBridge.initNavigation((route) {
    appRouterGo(route);
  });

  runApp(const ProviderScope(child: NokkonApp()));
}
