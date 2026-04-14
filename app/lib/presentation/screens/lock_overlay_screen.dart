import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../platform/method_channel.dart';
import '../providers/unlock_provider.dart';
import '../widgets/invite_link_flow.dart';

class LockOverlayScreen extends ConsumerStatefulWidget {
  final String packageName;

  const LockOverlayScreen({super.key, required this.packageName});

  @override
  ConsumerState<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends ConsumerState<LockOverlayScreen> {
  String _pinInput = '';
  String? _error;
  bool _delayActive = false;
  Duration _remaining = const Duration(minutes: 20);
  Timer? _timer;
  bool _exitedByUnlock = false;

  @override
  void dispose() {
    _timer?.cancel();
    if (!_exitedByUnlock) {
      // Strict exit rule: if user leaves without unlocking, force HOME.
      // (Avoids returning to Settings / blocked app state via recents/back.)
      unawaited(PlatformBridge.goHome());
    }
    super.dispose();
  }

  String get _appLabel {
    const map = {
      'com.impulsecontrol': 'NOKKON',
      'com.google.android.youtube': 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.snapchat.android': 'Snapchat',
      'com.android.settings': 'Settings',
      'com.android.vending': 'Google Play',
    };
    return map[widget.packageName] ?? 'App';
  }

  Future<Map<String, String>> _loadQuote() async {
    try {
      final str =
          await DefaultAssetBundle.of(context).loadString('assets/quotes.json');
      final list = jsonDecode(str) as List<dynamic>;
      if (list.isEmpty) {
        return {
          'quote': 'Take a breath. You are in control.',
          'author': '',
        };
      }
      final item = list[(DateTime.now().millisecondsSinceEpoch) % list.length];
      if (item is Map) {
        return {
          'quote': item['quote'] as String? ??
              'Take a breath. You are in control.',
          'author': item['author'] as String? ?? '',
        };
      }
    } catch (_) {}
    return {'quote': 'Take a breath. You are in control.', 'author': ''};
  }

  void _startDelay() {
    if (_delayActive) return;
    setState(() {
      _delayActive = true;
      _remaining = const Duration(minutes: 20);
      _error = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        t.cancel();
        await ref.read(unlockProvider.notifier).grantDelayedAccess(
              onUnlocked: () {
                if (mounted) context.go('/home');
              },
            );
        _exitedByUnlock = true;
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  Future<void> _unlockWithPin() async {
    if (_pinInput.length != 4) {
      setState(() => _error = 'Enter a 4-digit PIN');
      return;
    }
    final err =
        await ref.read(unlockProvider.notifier).unlockWithPin(_pinInput);
    if (!mounted) return;
    if (err == null) {
      _exitedByUnlock = true;
      context.go('/home');
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(unlockProvider);
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        body: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xF0161820),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.14),
                          blurRadius: 36,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header ──────────────────────────────────────
                        Row(
                          children: [
                            Icon(Icons.shield_rounded,
                                color:
                                    AppTheme.primary.withValues(alpha: 0.95),
                                size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              'NOKKON',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/home'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── App blocked title ────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppTheme.danger.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$_appLabel is blocked',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Screen time today: 6m 34s',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Quote ────────────────────────────────────────
                        FutureBuilder<Map<String, String>>(
                          future: _loadQuote(),
                          builder: (_, snap) {
                            final q = snap.data?['quote'] ??
                                'Take a breath. You are in control.';
                            final author = snap.data?['author'] ?? '';
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '"$q"',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.82),
                                      fontSize: 13,
                                      height: 1.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  if (author.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '— $author',
                                      style: TextStyle(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── PIN unlock (primary action) ──────────────────
                        if (lock.isPinSet) ...[
                          Text(
                            'Enter your PIN to unlock',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            onChanged: (v) => setState(() {
                              _pinInput = v;
                              _error = null;
                            }),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              letterSpacing: 12,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  letterSpacing: 8,
                                  fontSize: 22),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.07),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppTheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _unlockWithPin,
                              icon: const Icon(Icons.lock_open_rounded,
                                  size: 20),
                              label: const Text('Unlock with PIN'),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Divider ─────────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.12))),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.12))),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── No-PIN warning ───────────────────────────────
                        if (!lock.isPinSet) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppTheme.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color:
                                        AppTheme.amber.withValues(alpha: 0.85),
                                    size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No PIN set yet. Generate an invite link and send it to a trusted contact so they can set your PIN.',
                                    style: TextStyle(
                                      color: AppTheme.amber
                                          .withValues(alpha: 0.9),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  InviteLinkFlow.generateInviteLinkWithOptionalPin(
                                context,
                                ref,
                                packageName: widget.packageName,
                              ),
                              icon: const Icon(Icons.link_rounded, size: 20),
                              label: const Text('Generate invite link'),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Wait 20 minutes (secondary) ──────────────────
                        if (_delayActive) ...[
                          Text(
                            '$m:$s',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primary.withValues(alpha: 0.95),
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep this screen open — it will unlock automatically',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (lock.isPinSet && !_delayActive)
                                ? _startDelay
                                : null,
                            icon: const Icon(Icons.schedule_rounded, size: 20),
                            label: Text(_delayActive
                                ? 'Waiting…'
                                : 'Wait 20 minutes'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                        if (!_delayActive) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Helps reduce the urge. App opens when the timer ends.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],

                        // ── New invite link (when PIN is set) ────────────
                        if (lock.isPinSet) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton.icon(
                              onPressed: () =>
                                  InviteLinkFlow.generateInviteLinkWithOptionalPin(
                                context,
                                ref,
                                packageName: widget.packageName,
                              ),
                              icon: Icon(Icons.link_rounded,
                                  size: 16,
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.7)),
                              label: Text(
                                'Generate new invite link',
                                style: TextStyle(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
