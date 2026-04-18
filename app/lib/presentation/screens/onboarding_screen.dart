import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../platform/method_channel.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  bool _accessEnabled = false;
  Timer? _poll;

  static const _total = 3;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final ok = await PlatformBridge.isAccessibilityEnabled();
    if (mounted) setState(() => _accessEnabled = ok);
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      final ok = await PlatformBridge.isAccessibilityEnabled();
      if (!mounted) return;
      if (ok && !_accessEnabled) {
        setState(() => _accessEnabled = true);
        _poll?.cancel();
      }
    });
  }

  Future<void> _finish() async {
    _poll?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_page < _total - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DotRow(current: _page, total: _total),
                  if (_page < _total - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 64),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == _total - 1) _startPolling();
                },
                children: [
                  const _WelcomePage(),
                  const _PrivacyPage(),
                  _AccessibilityPage(
                    enabled: _accessEnabled,
                    onOpenSettings: () async {
                      await PlatformBridge.openAccessibilitySettings();
                      _startPolling();
                    },
                  ),
                ],
              ),
            ),
            _BottomCta(
              page: _page,
              total: _total,
              accessEnabled: _accessEnabled,
              onNext: _next,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Page 1 — Welcome
// ─────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  static const _features = [
    (
      Icons.block_rounded,
      'Block Shorts & Reels',
      'Stop addictive short-form video before it pulls you in.'
    ),
    (
      Icons.people_alt_rounded,
      'Trusted-person PIN',
      'Someone you trust holds the code — not you. That\'s the point.'
    ),
    (
      Icons.bar_chart_rounded,
      'Daily usage insight',
      'See exactly how much time you recover each day.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF596DFF), Color(0xFF9BA8FF)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'Take back\nyour focus.',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NeuroLock helps you spend less time on addictive features — while keeping full control of your phone.',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.9),
              fontSize: 16,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 36),
          ..._features.map(
            (f) => _FeatureRow(icon: f.$1, label: f.$2, sub: f.$3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Page 2 — Privacy Promise
// ─────────────────────────────────────────────────────────────

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 48,
                color: AppTheme.success,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Your data\nstays yours.',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Accessibility access can feel invasive. Here\'s exactly what it means for NeuroLock — in plain language.',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          const _PrivacyCard(
            icon: Icons.check_circle_rounded,
            color: AppTheme.success,
            title: 'WHAT WE DO',
            items: [
              'Detect which app screen is in the foreground',
              'Block specific addictive surfaces (Shorts, Reels, Explore)',
              'Prevent uninstall when your trusted PIN is active',
            ],
          ),
          const SizedBox(height: 14),
          const _PrivacyCard(
            icon: Icons.cancel_rounded,
            color: AppTheme.danger,
            title: 'WHAT WE NEVER DO',
            items: [
              'Read your messages, emails, or private content',
              'Record your screen, audio, or keystrokes',
              'Store any personal data from your device',
              'Share anything with advertisers or third parties',
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Page 3 — Accessibility Setup
// ─────────────────────────────────────────────────────────────

class _AccessibilityPage extends StatelessWidget {
  final bool enabled;
  final VoidCallback onOpenSettings;

  const _AccessibilityPage({
    required this.enabled,
    required this.onOpenSettings,
  });

  static const _steps = [
    'Tap "Open Settings" below',
    'Scroll to find NeuroLock in the list',
    'Tap NeuroLock and toggle it ON',
    'Come back here — we\'ll detect it automatically',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.success.withValues(alpha: 0.13)
                    : AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: enabled
                      ? AppTheme.success.withValues(alpha: 0.28)
                      : AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                enabled
                    ? Icons.check_circle_rounded
                    : Icons.accessibility_new_rounded,
                size: 50,
                color: enabled ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: enabled
                ? const Text(
                    'You\'re all set!',
                    key: ValueKey('done'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  )
                : const Text(
                    'One permission\nto protect you.',
                    key: ValueKey('pending'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(enabled),
              enabled
                  ? 'Accessibility is active. NeuroLock can now detect and block addictive screens in real time.'
                  : 'NeuroLock uses Android\'s Accessibility API only to detect the foreground screen — nothing else.',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
          if (!enabled) ...[
            const SizedBox(height: 32),
            const Text(
              'How to enable it',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 18),
            ..._steps.asMap().entries.map(
                  (e) => _StepRow(number: e.key + 1, label: e.value),
                ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 19),
                label: const Text('Open Settings'),
              ),
            ),
          ],
          if (enabled) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NeuroLock is ready to protect your focus.',
                      style: TextStyle(
                        color: AppTheme.textPrimary.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  const _PrivacyCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      icon,
                      size: 13,
                      color: color.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        color:
                            AppTheme.textSecondary.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.45,
                      ),
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

class _StepRow extends StatelessWidget {
  final int number;
  final String label;

  const _StepRow({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  final int current;
  final int total;

  const _DotRow({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 24.0 : 8.0,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary
                : AppTheme.textSecondary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _BottomCta extends StatelessWidget {
  final int page;
  final int total;
  final bool accessEnabled;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _BottomCta({
    required this.page,
    required this.total,
    required this.accessEnabled,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLast && accessEnabled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onFinish,
                child: const Text('Get started'),
              ),
            )
          else if (isLast && !accessEnabled)
            TextButton(
              onPressed: onFinish,
              child: Text(
                "I'll enable it later",
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
