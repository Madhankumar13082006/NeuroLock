import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/terms_and_conditions_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/lock_overlay_screen.dart';
import 'presentation/screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

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
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable:
      _GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (ctx, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;
    final onAuth = loc == '/login' || loc == '/register';

    if (user == null && !onAuth) {
      return '/login';
    }
    // Only auto-redirect from /login → /home, not from /register.
    // During registration Firebase briefly signs in the user before
    // we sign them out; redirecting /register → /home at that moment
    // skips the success snackbar and lands the user in the app unlocked.
    if (user != null && loc == '/login') {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/terms',
      builder: (_, __) => const TermsAndConditionsScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const MainShellScreen(),
    ),
    GoRoute(
      path: '/lock/:packageName',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => LockOverlayScreen(
        packageName: state.pathParameters['packageName'] ?? '',
      ),
    ),
  ],
);

void appRouterGo(String route) {
  _router.go(route);
}

class NeuroLockApp extends StatelessWidget {
  const NeuroLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeuroLock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
