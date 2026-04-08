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

  Future<void> _register() async {
    setState(() => _localError = null);
    if (_name.text.trim().isEmpty) {
      setState(() => _localError = 'Enter your name.');
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(_email.text, _pass.text, _name.text);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Account created! Please sign in.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => context.pop(),
                child: const Row(children: [
                  Icon(Icons.arrow_back_ios_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 4),
                  Text('Back to login',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ]),
              ),
              const SizedBox(height: 30),
              Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.only(bottom: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person_add_rounded,
                    size: 40, color: AppTheme.primary),
              ),
              const Text('Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('Start your journey to digital wellness',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 36),
              TextField(
                controller: _name,
                keyboardType: TextInputType.name,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined,
                      color: AppTheme.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                onSubmitted: (_) => _register(),
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(err,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : _register,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
