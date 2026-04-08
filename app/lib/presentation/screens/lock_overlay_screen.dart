import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../providers/unlock_provider.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<String> _loadQuote() async {
    try {
      final str =
          await DefaultAssetBundle.of(context).loadString('assets/quotes.json');
      final list = jsonDecode(str) as List<dynamic>;
      if (list.isEmpty) return 'Take a breath. You are in control.';
      final item = list[(DateTime.now().millisecondsSinceEpoch) % list.length];
      return (item is Map && item['quote'] is String)
          ? item['quote'] as String
          : 'Take a breath. You are in control.';
    } catch (_) {
      return 'Take a breath. You are in control.';
    }
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
        await ref
            .read(unlockProvider.notifier)
            .grantDelayedAccess(onUnlocked: () => context.go('/home'));
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
    final ok = await ref.read(unlockProvider.notifier).unlockWithPin(_pinInput);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() => _error = 'Invalid PIN');
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
        backgroundColor: const Color(0xFF0D0D1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_rounded, size: 56, color: AppTheme.primary),
                const SizedBox(height: 12),
                const Text('Feature Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _loadQuote(),
                  builder: (_, snap) => Text(
                    snap.data ?? 'Take a breath. You are in control.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 20),
                if (!lock.isPinSet) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Waiting for trusted person to set PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFBBF24)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_delayActive)
                  Text('Access after delay: $m:$s',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  onChanged: (v) => _pinInput = v,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'PIN',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: lock.isPinSet ? _unlockWithPin : null,
                  child: const Text('Unlock with PIN (1 hour)'),
                ),
                TextButton(
                  onPressed: (lock.isPinSet && !_delayActive) ? _startDelay : null,
                  child: const Text('Access after delay (20 min)'),
                ),
                if (_error != null)
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.danger)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
