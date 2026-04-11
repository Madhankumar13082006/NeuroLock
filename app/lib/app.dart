import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/lock_overlay_screen.dart';

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

class NokkonApp extends StatelessWidget {
  const NokkonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NOKKON',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
