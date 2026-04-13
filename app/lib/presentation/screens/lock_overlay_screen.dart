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
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xE6161820),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          blurRadius: 32,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_rounded,
                                    color: AppTheme.primary.withValues(alpha: 0.95),
                                    size: 26),
                                const SizedBox(width: 8),
                                const Text(
                                  'NOKKON',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => context.go('/home'),
                              icon: Icon(Icons.more_vert_rounded,
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_appLabel is blocked',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Screen time today: 6m 34s',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
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
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '"$q"',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 14,
                                      height: 1.45,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  if (author.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      author,
                                      style: TextStyle(
                                        color:
                                            AppTheme.primary.withValues(alpha: 0.85),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        if (!lock.isPinSet) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'No PIN set. Generate a new invite link and send it to your trusted contact so they can set a new PIN.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.amber.withValues(alpha: 0.95),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
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
                              label: const Text('Generate new invite link'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (lock.isPinSet) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  InviteLinkFlow.generateInviteLinkWithOptionalPin(
                                context,
                                ref,
                                packageName: widget.packageName,
                              ),
                              icon: const Icon(Icons.link_rounded, size: 20),
                              label: const Text('New invite link (enter PIN)'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_delayActive)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Keep this screen open: $m:$s',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.primary.withValues(alpha: 0.95),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          'Open in 20 minutes or enter PIN to unlock.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          onChanged: (v) => _pinInput = v,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            hintStyle:
                                TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (lock.isPinSet && !_delayActive)
                                ? _startDelay
                                : null,
                            icon: const Icon(Icons.schedule_rounded, size: 20),
                            label: const Text('Wait 20 minutes'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reduce the urge to unlock.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: lock.isPinSet ? _unlockWithPin : null,
                            icon: const Icon(Icons.lock_open_rounded, size: 20),
                            label: const Text('Unlock with PIN'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.danger),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'This feature is locked via NOKKON blocking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: AppTheme.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
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
