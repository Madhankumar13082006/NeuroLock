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
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _agree = false;
  String? _localError;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _localError = null);
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _localError = 'Enter your first and last name.');
      return;
    }
    if (!_agree) {
      setState(() => _localError = 'Please agree to the Terms & Conditions.');
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
    final name = '${_first.text.trim()} ${_last.text.trim()}';
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .register(_email.text, _pass.text, name);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please sign in.'),
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
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text('Back to login',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        size: 32, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'NOKKON',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Create an account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _first,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _last,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                    ),
                  ),
                ],
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
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textSecondary,
                    ),
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
                  labelText: 'Confirm password',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agree = !_agree),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'I agree to the Terms & Conditions',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.95),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (err != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    err,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
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
                          strokeWidth: 2,
                          color: Color(0xFF1A1A1A),
                        ),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
