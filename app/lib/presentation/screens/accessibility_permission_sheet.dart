import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../platform/method_channel.dart';

/// Shows a 2-screen bottom sheet:
///   Screen 1 — WHY: what the permission is used for (builds trust)
///   Screen 2 — HOW: step-by-step guide + "Open Settings" button
///
/// Auto-dismisses once accessibility is detected as enabled.
Future<void> showAccessibilityPermissionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    routeSettings: const RouteSettings(name: 'accessibility_sheet'),
    builder: (_) => const _SheetContent(),
  );
}

// ─────────────────────────────────────────────────────────────

class _SheetContent extends StatefulWidget {
  const _SheetContent();

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  bool _showHow = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Poll immediately so sheet auto-closes if accessibility is already on
    // or the user enables it without tapping "Open Settings".
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final ok = await PlatformBridge.isAccessibilityEnabled();
      if (!mounted) return;
      if (ok) {
        _poll?.cancel();
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
        child: _showHow
            ? _HowScreen(
                key: const ValueKey('how'),
                onOpenSettings: () async {
                  await PlatformBridge.openAccessibilitySettings();
                  _startPolling();
                },
                onBack: () => setState(() => _showHow = false),
              )
            : _WhyScreen(
                key: const ValueKey('why'),
                onContinue: () => setState(() => _showHow = true),
                onDismiss: () => Navigator.pop(context),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 1 — WHY
// ─────────────────────────────────────────────────────────────

class _WhyScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  const _WhyScreen({
    super.key,
    required this.onContinue,
    required this.onDismiss,
  });

  static const _points = [
    (
      Icons.visibility_outlined,
      'Detect the foreground screen',
      'So we know when a blocked app or feature opens.'
    ),
    (
      Icons.block_rounded,
      'Block addictive surfaces',
      'Shorts, Reels, Explore — the specific parts you chose to block.'
    ),
    (
      Icons.lock_outline_rounded,
      'Guard against uninstall',
      'When a PIN is active, we prevent bypass attempts.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // Icon + title row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accessibility Access',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Required for blocking to work',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // Privacy note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 16, color: AppTheme.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We never read messages, record your screen, or share any data.',
                    style: TextStyle(
                      color: AppTheme.textPrimary.withValues(alpha: 0.88),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Points
          ..._points.map((p) => _PermissionPoint(
                icon: p.$1,
                title: p.$2,
                sub: p.$3,
              )),
          const SizedBox(height: 20),
          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Got it — show me how'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDismiss,
              child: Text(
                'Not now',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 2 — HOW
// ─────────────────────────────────────────────────────────────

class _HowScreen extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _HowScreen({
    super.key,
    required this.onOpenSettings,
    required this.onBack,
  });

  static const _steps = [
    'Tap "Open Settings" below',
    'Scroll down to find NeuroLock',
    'Tap NeuroLock and toggle it ON',
    'Press Back — this sheet will close automatically',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Back link
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded,
                    size: 16,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Why is this needed?',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'How to enable it',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Follow these steps — it takes about 10 seconds.',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ..._steps.asMap().entries.map(
                (e) => _HowStep(number: e.key + 1, label: e.value),
              ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 19),
              label: const Text('Open Settings'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'We\'ll detect it automatically when you come back.',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _PermissionPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _PermissionPoint({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.cardBorder.withValues(alpha: 0.7)),
            ),
            child: Icon(icon, size: 17, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
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

class _HowStep extends StatelessWidget {
  final int number;
  final String label;

  const _HowStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF596DFF), Color(0xFF7C8CFF)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
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
