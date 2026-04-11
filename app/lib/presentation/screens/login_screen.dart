import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  Future<void> _login() async {
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .login(_email.text, _pass.text);
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(authNotifierProvider);
    final loading = st.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 46, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'NOKKON',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to manage in-app blocking and invite links',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 44),
              _label('Email Address'),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textSecondary,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (st.status == AuthStatus.error) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(st.error ?? 'Error',
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: loading ? null : _login,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1A1A),
                        ),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account? ",
                    style: TextStyle(color: AppTheme.textSecondary)),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: const Text('Register',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));
}
