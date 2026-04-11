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

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .login(_email.text, _pass.text);
    if (!mounted) return;
    if (ok) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(authNotifierProvider);
    final loading = st.status == AuthStatus.loading;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle radial brand glow in the top-left corner
          Positioned(
            top: -120,
            left: -100,
            child: _BrandGlow(color: AppTheme.primary, size: 320),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: _BrandGlow(color: AppTheme.accent, size: 360, opacity: 0.18),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: AppTheme.glow(AppTheme.primary),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          size: 46, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to take back control of your day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 44),
                  _label('Email address'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppTheme.textSecondary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      suffixIcon: IconButton(
                        splashRadius: 20,
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (st.status == AuthStatus.error) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: st.error ?? 'Something went wrong'),
                  ],
                  const SizedBox(height: 28),
                  _GradientButton(
                    label: 'Sign in',
                    loading: loading,
                    onTap: loading ? null : _login,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/register'),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: AppTheme.primarySoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      );
}

/// Soft circular glow used as a background accent on auth screens.
class _BrandGlow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _BrandGlow({
    required this.color,
    required this.size,
    this.opacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled gradient primary button used across auth screens.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: disabled
              ? const LinearGradient(
                  colors: [Color(0xFF2C2C4A), Color(0xFF2C2C4A)],
                )
              : AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              disabled ? null : AppTheme.glow(AppTheme.primary, opacity: 0.28),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
