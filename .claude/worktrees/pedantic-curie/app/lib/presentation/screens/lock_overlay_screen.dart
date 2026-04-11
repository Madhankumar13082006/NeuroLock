import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../providers/unlock_provider.dart';
import 'pin_entry_screen.dart';

/// Full-screen lock overlay shown when the user tries to access a
/// blocked feature. Designed for friction: a deliberate pause, a quote,
/// and only two ways out — PIN from a trusted person, or a 20-minute wait.
class LockOverlayScreen extends ConsumerStatefulWidget {
  final String packageName;
  const LockOverlayScreen({super.key, required this.packageName});

  @override
  ConsumerState<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends ConsumerState<LockOverlayScreen>
    with SingleTickerProviderStateMixin {
  static const _delayDuration = Duration(minutes: 20);

  late final AnimationController _pulse;
  bool _delayActive = false;
  Duration _remaining = _delayDuration;
  Timer? _timer;
  String? _error;
  String? _quote;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadQuote();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    try {
      final str = await DefaultAssetBundle.of(context)
          .loadString('assets/quotes.json');
      final list = jsonDecode(str) as List<dynamic>;
      if (list.isEmpty) return;
      final pick =
          list[(DateTime.now().millisecondsSinceEpoch) % list.length];
      final text = (pick is Map && pick['quote'] is String)
          ? pick['quote'] as String
          : (pick is String ? pick : null);
      if (text != null && mounted) {
        setState(() => _quote = text);
      }
    } catch (_) {
      // Asset missing — fall back to default below.
    }
  }

  void _startDelay() {
    if (_delayActive) return;
    HapticFeedback.lightImpact();
    setState(() {
      _delayActive = true;
      _remaining = _delayDuration;
      _error = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining.inSeconds <= 1) {
        t.cancel();
        await ref.read(unlockProvider.notifier).grantDelayedAccess(
          onUnlocked: () {
            if (mounted) context.go('/home');
          },
        );
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  Future<void> _unlockWithPin() async {
    HapticFeedback.lightImpact();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PinEntryDialog(title: 'Enter PIN'),
    );
    if (pin == null || pin.length != 4) return;
    if (!mounted) return;
    final ok = await ref.read(unlockProvider.notifier).unlockWithPin(pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      context.go('/home');
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Invalid PIN. Ask your trusted person.');
    }
  }

  String _appLabelFromPackage(String pkg) {
    switch (pkg) {
      case 'com.google.android.youtube':
        return 'YouTube';
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.zhiliaoapp.musically':
        return 'TikTok';
      case 'com.twitter.android':
        return 'X (Twitter)';
      default:
        return pkg.split('.').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(unlockProvider);
    final appLabel = _appLabelFromPackage(widget.packageName);
    final progress = 1.0 -
        (_remaining.inSeconds / _delayDuration.inSeconds).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A14),
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.lockGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                children: [
                  // Pulsing lock badge
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) {
                      final t = Curves.easeInOut.transform(_pulse.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 160 + (12 * t),
                            height: 160 + (12 * t),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary
                                  .withValues(alpha: 0.10 + 0.06 * t),
                            ),
                          ),
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.brandGradient,
                              boxShadow: AppTheme.glow(AppTheme.primary,
                                  opacity: 0.45),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Take a breath.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You tried to open $appLabel.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Quote card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      _quote ??
                          'You are not your impulse. The next minute is yours to choose.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!lock.isPinSet) _waitingForPinBanner(),
                  if (_delayActive) _delayCountdown(progress),
                  if (!_delayActive) ...[
                    if (lock.isPinSet)
                      _PrimaryAction(
                        icon: Icons.lock_open_rounded,
                        title: 'Unlock with PIN',
                        subtitle: '1 hour of access',
                        onTap: _unlockWithPin,
                      ),
                    if (lock.isPinSet) const SizedBox(height: 12),
                    _SecondaryAction(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Wait 20 minutes',
                      subtitle: 'Then 10 minutes of access',
                      onTap: _startDelay,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _waitingForPinBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waiting for trusted person to set PIN.\nThe wait timer is still available.',
              style: TextStyle(
                color: AppTheme.warning,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _delayCountdown(double progress) {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: _CountdownRingPainter(progress: progress),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$m:$s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'until 10-minute access',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Stay with the discomfort.\nIt always passes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PrimaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.glow(AppTheme.primary, opacity: 0.35),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SecondaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primarySoft, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Circular progress ring used for the 20-minute delay countdown.
class _CountdownRingPainter extends CustomPainter {
  final double progress; // 0..1
  _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);

    final shader = SweepGradient(
      colors: const [AppTheme.primary, AppTheme.accent, AppTheme.primarySoft],
      stops: const [0.0, 0.6, 1.0],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final progressPaint = Paint()
      ..shader = shader
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter old) =>
      old.progress != progress;
}
