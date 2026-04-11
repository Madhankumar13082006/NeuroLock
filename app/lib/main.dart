import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Allow Android accessibility service to navigate into Flutter and report blocks.
  PlatformBridge.initBridge(
    onNavigate: appRouterGo,
    onBlockTriggered: kDebugMode
        ? (payload) {
            // Feature-level block fired (native); hook analytics here if needed.
            debugPrint('NOKKON block: $payload');
          }
        : null,
  );

  runApp(const ProviderScope(child: NokkonApp()));
}
