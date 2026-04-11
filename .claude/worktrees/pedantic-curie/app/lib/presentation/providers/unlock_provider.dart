import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_service.dart';
import '../../platform/method_channel.dart';
import 'auth_provider.dart';

class UnlockState {
  final bool isLocked;
  final bool isPinSet;
  final bool isUnlocked;
  final DateTime? expiresAt;
  final DateTime? delayTimer;

  const UnlockState({
    this.isLocked = true,
    this.isPinSet = false,
    this.isUnlocked = false,
    this.expiresAt,
    this.delayTimer,
  });

  Duration get remaining {
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

class UnlockNotifier extends StateNotifier<UnlockState> {
  final FirebaseService _svc;
  Timer? _timer;
  StreamSubscription<LockStateDoc>? _sub;

  UnlockNotifier(this._svc) : super(const UnlockState()) {
    _startWatching();
  }

  void _startWatching() {
    _sub?.cancel();
    _sub = _svc.watchLockState().listen((doc) async {
      final now = DateTime.now();
      final unlocked = doc.unlockExpiry != null && doc.unlockExpiry!.isAfter(now);
      state = UnlockState(
        isLocked: doc.isLocked,
        isPinSet: doc.isPinSet,
        isUnlocked: unlocked,
        expiresAt: doc.unlockExpiry,
        delayTimer: doc.delayTimer,
      );
      await PlatformBridge.setPinSet(doc.isPinSet);
      await PlatformBridge.setUnlockUntilMs(
        unlocked ? doc.unlockExpiry!.millisecondsSinceEpoch : null,
      );
      if (unlocked) {
        _startExpiryTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!state.isPinSet) return false;
    final ok = await _svc.verifyPin(pin);
    if (!ok) return false;
    return true;
  }

  Future<void> grantDelayedAccess({required Function() onUnlocked}) async {
    final expiry = DateTime.now().add(const Duration(minutes: 10));
    await _svc.saveLocalUnlock(expiry);
    state = UnlockState(isUnlocked: true, expiresAt: expiry);
    await PlatformBridge.setUnlockUntilMs(expiry.millisecondsSinceEpoch);
    _startExpiryTimer();
    onUnlocked();
  }

  void _startExpiryTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.expired) {
        state = UnlockState(
          isLocked: state.isLocked,
          isPinSet: state.isPinSet,
          isUnlocked: false,
          expiresAt: null,
          delayTimer: state.delayTimer,
        );
        _timer?.cancel();
        PlatformBridge.setUnlockUntilMs(null);
      }
    });
  }

  void lock() {
    _timer?.cancel();
    state = const UnlockState();
    PlatformBridge.setUnlockUntilMs(null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final unlockProvider = StateNotifierProvider<UnlockNotifier, UnlockState>(
    (ref) => UnlockNotifier(ref.watch(firebaseServiceProvider)));
