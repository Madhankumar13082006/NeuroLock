import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_list.dart';
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
  Timer? _pollTimer;
  StreamSubscription<LockStateDoc>? _sub;
  // Tracks whether the active unlock window was opened by entering the PIN
  // (vs. the 20-minute delay escape route). When a PIN-based unlock expires we
  // must clear the stored PIN hash so the user has to send a fresh invite link
  // and their trusted contact sets a brand-new PIN.
  bool _unlockedViaPin = false;

  UnlockNotifier(this._svc) : super(const UnlockState()) {
    _startWatching();
    _startPolling();
  }

  void _startWatching() {
    _sub?.cancel();
    _sub = _svc.watchLockState().listen((doc) async {
      await _applyLockDoc(doc);
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final doc = await _svc.getLockState();
        await _applyLockDoc(doc);
      } catch (_) {}
    });
  }

  Future<void> _applyLockDoc(LockStateDoc doc) async {
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
    if (doc.isPinSet) {
      await PlatformBridge.setInviteRotationPending(false);
    }
    // Cache the trusted PIN hash locally so PIN unlock works offline.
    await _svc.cacheTrustedPinHashForOffline(doc.currentPinHash);
    await PlatformBridge.setUnlockUntilMs(
      unlocked ? doc.unlockExpiry!.millisecondsSinceEpoch : null,
    );
    if (unlocked) {
      _scheduleUnlockExpiryTimer();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _onUnlockWindowEnded() async {
    _timer?.cancel();
    final wasPin = _unlockedViaPin;
    _unlockedViaPin = false;
    try {
      await _svc.clearUnlockExpiry();
      // If the unlock was granted via the trusted PIN, invalidate that PIN now.
      // This forces the user to generate a fresh invite link and have their
      // trusted contact set a brand-new PIN before the feature can be unlocked
      // again — preventing them from silently reusing the old PIN.
      if (wasPin) await _svc.clearCurrentPin();
    } catch (_) {}
    state = UnlockState(
      isLocked: state.isLocked,
      // If PIN was cleared above, reflect that immediately in local state so the
      // UI shows "Generate invite link" without waiting for the Firestore stream.
      isPinSet: wasPin ? false : state.isPinSet,
      isUnlocked: false,
      expiresAt: null,
      delayTimer: state.delayTimer,
    );
    await PlatformBridge.setUnlockUntilMs(null);
    if (wasPin) {
      await PlatformBridge.setPinSet(false);
      await PlatformBridge.setInviteRotationPending(false);
    }
  }

  void _scheduleUnlockExpiryTimer() {
    _timer?.cancel();
    final exp = state.expiresAt;
    if (exp == null) return;
    final ms = exp.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) {
      unawaited(_onUnlockWindowEnded());
      return;
    }
    final wait = ms.clamp(500, 24 * 60 * 60 * 1000);
    _timer = Timer(Duration(milliseconds: wait), () {
      unawaited(_onUnlockWindowEnded());
    });
  }

  /// Returns `null` on success, or an error message for the UI.
  Future<String?> unlockWithPin(String pin) async {
    if (!state.isPinSet) {
      return 'PIN is not set yet. Ask your friend to open the invite link first.';
    }
    final res = await _svc.verifyPin(pin);
    if (!res.ok) {
      return res.message ?? 'Invalid PIN';
    }
    if (res.unlockUntilMs != null) {
      _unlockedViaPin = true; // mark so expiry clears the PIN hash
      final until =
          DateTime.fromMillisecondsSinceEpoch(res.unlockUntilMs!);
      state = UnlockState(
        isLocked: state.isLocked,
        isPinSet: state.isPinSet,
        isUnlocked: true,
        expiresAt: until,
        delayTimer: state.delayTimer,
      );
      await PlatformBridge.setUnlockUntilMs(res.unlockUntilMs!);
      await PlatformBridge.setPinSet(true);
      _scheduleUnlockExpiryTimer();
    }
    return null;
  }

  /// Removes the trusted PIN globally (for whole NOKKON) after verifying it.
  ///
  /// After removal:
  /// - blocks remain active (invite-rotation pending keeps native rules armed)
  /// - lock screen will show "blocked" but won't offer PIN unlock
  Future<String?> removeTrustedPin(String pin) async {
    if (!state.isPinSet) return 'No PIN set.';

    final res = await _svc.verifyPinIdentityLocalFirst(pin);
    if (!res.ok) {
      return res.message ?? 'Invalid PIN';
    }

    try {
      // Reset all protections to OFF when PIN is removed.
      await PlatformBridge.setInviteRotationPending(false);

      await _svc.clearUnlockExpiry();
      await _svc.clearCurrentPin();
      await _svc.clearAllBlocks();
      await _svc.clearOfflinePinCache();
      await _clearAllLocalFeatureFlags();

      await PlatformBridge.setUnlockUntilMs(null);
      await PlatformBridge.setPinSet(false);
      await PlatformBridge.setBlockConfig('{}');
    } catch (e) {
      return 'Could not remove PIN: $e';
    }

    state = UnlockState(
      isLocked: state.isLocked,
      isPinSet: false,
      isUnlocked: false,
      expiresAt: null,
      delayTimer: state.delayTimer,
    );
    return null;
  }

  Future<void> _clearAllLocalFeatureFlags() async {
    final prefs = await SharedPreferences.getInstance();
    for (final app in kSupportedApps) {
      for (final feature in app.features) {
        await prefs.remove('${app.packageName}:${feature.key}');
      }
    }
  }

  Future<void> grantDelayedAccess({required Function() onUnlocked}) async {
    _unlockedViaPin = false; // delay path — do NOT clear PIN on expiry
    final expiry = DateTime.now().add(const Duration(hours: 1));
    await _svc.saveLocalUnlock(expiry);
    state = UnlockState(
      isLocked: state.isLocked,
      isPinSet: state.isPinSet,
      isUnlocked: true,
      expiresAt: expiry,
      delayTimer: state.delayTimer,
    );
    await PlatformBridge.setUnlockUntilMs(expiry.millisecondsSinceEpoch);
    await PlatformBridge.setPinSet(state.isPinSet);
    _scheduleUnlockExpiryTimer();
    onUnlocked();
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
    _pollTimer?.cancel();
    super.dispose();
  }
}

final unlockProvider = StateNotifierProvider<UnlockNotifier, UnlockState>(
    (ref) => UnlockNotifier(ref.watch(firebaseServiceProvider)));
