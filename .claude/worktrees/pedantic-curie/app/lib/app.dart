import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/contacts_screen.dart';
import 'presentation/screens/lock_overlay_screen.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _router = GoRouter(
  // If anonymous auth works, redirect() will push users to /home immediately.
  initialLocation: '/home',
  refreshListenable:
      _GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (ctx, state) {
    final user = FirebaseAuth.instance.currentUser;
    final onAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    // Not logged in and not on login/register → redirect to login
    if (user == null && !onAuth) {
      return '/login';
    }

    // Logged in and on login/register → redirect to home
    if (user != null && onAuth) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'contacts',
          builder: (_, __) => const ContactsScreen(),
        ),
        GoRoute(
          path: 'lock/:packageName',
          builder: (_, state) => LockOverlayScreen(
            packageName: state.pathParameters['packageName'] ?? '',
          ),
        ),
      ],
    ),
  ],
);

/// Used by Android accessibility service to force navigation.
void appRouterGo(String route) {
  _router.go(route);
}

class NokkonApp extends StatelessWidget {
  const NokkonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nokkon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
