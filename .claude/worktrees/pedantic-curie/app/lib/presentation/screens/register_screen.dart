import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() => _localError = null);
    if (_name.text.trim().isEmpty) {
      setState(() => _localError = 'Please enter your name.');
      return;
    }
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _localError = 'Please enter a valid email.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(_email.text, _pass.text, _name.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: AppTheme.success, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Account created — please sign in.'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(authNotifierProvider);
    final loading = st.status == AuthStatus.loading;
    final err =
        _localError ?? (st.status == AuthStatus.error ? st.error : null);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -140,
            right: -120,
            child: _GlowDot(color: AppTheme.primary, size: 320),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child:
                _GlowDot(color: AppTheme.accent, size: 320, opacity: 0.16),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/login'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: AppTheme.textSecondary),
                            SizedBox(width: 6),
                            Text(
                              'Back to login',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 40,
                        color: AppTheme.primarySoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One small step to break the scroll loop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _name,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password (min. 6 characters)',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
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
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirm,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onSubmitted: (_) => _register(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(
                        Icons.lock_person_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              err,
                              style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: loading ? null : _register,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: loading
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF2C2C4A),
                                  Color(0xFF2C2C4A)
                                ],
                              )
                            : AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: loading
                            ? null
                            : AppTheme.glow(AppTheme.primary, opacity: 0.28),
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
                          : const Text(
                              'Create account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'By creating an account you agree that a trusted person\n'
                    'will manage your unlock PIN. You will never see it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowDot({
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
