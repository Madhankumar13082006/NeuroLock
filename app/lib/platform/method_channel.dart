import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  static const _ch = MethodChannel('com.impulsecontrol/bridge');
  static void Function(String route)? _onNavigate;
  static void Function(Map<String, dynamic> payload)? _onBlockTriggered;

  /// Call once at app startup. Prefer [initBridge] to also receive block events.
  static void initNavigation(void Function(String route) onNavigate) {
    initBridge(onNavigate: onNavigate, onBlockTriggered: null);
  }

  /// Registers navigation from the accessibility service and optional block
  /// telemetry when a feature-level block fires on Android.
  static void initBridge({
    required void Function(String route) onNavigate,
    void Function(Map<String, dynamic> payload)? onBlockTriggered,
  }) {
    _onNavigate = onNavigate;
    _onBlockTriggered = onBlockTriggered;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'navigate':
          final route = call.arguments as String?;
          if (route != null && route.isNotEmpty) {
            _onNavigate?.call(route);
          }
          return null;
        case 'onBlockTriggered':
          final args = call.arguments;
          if (_onBlockTriggered != null && args is Map) {
            try {
              _onBlockTriggered!(Map<String, dynamic>.from(args));
            } catch (e, st) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: e,
                  stack: st,
                  library: 'PlatformBridge',
                ),
              );
            }
          }
          return null;
        default:
          return null;
      }
    });
  }

  static Future<void> openAccessibilitySettings() =>
      _ch.invokeMethod('openAccessibilitySettings');

  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _ch.invokeMethod('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Per-package feature keys, e.g. `{"com.google.android.youtube":["shorts"]}`.
  /// Native service uses this for Shorts-only vs full-app blocking.
  static Future<void> setBlockConfig(String rulesJson) =>
      _ch.invokeMethod('setBlockConfig', {'rulesJson': rulesJson});

  @Deprecated('Use setBlockConfig with full rules map')
  static Future<void> setBlockedApps(List<String> packages) =>
      _ch.invokeMethod('setBlockedApps', {'packages': packages});

  static Future<void> setUnlockUntilMs(int? untilMs) =>
      _ch.invokeMethod('setUnlockUntilMs', {'untilMs': untilMs});

  static Future<void> setPinSet(bool isPinSet) =>
      _ch.invokeMethod('setPinSet', {'isPinSet': isPinSet});

  /// While true, accessibility blocking stays armed using existing rules even
  /// if the trusted PIN was cleared for a fresh invite link.
  static Future<void> setInviteRotationPending(bool pending) =>
      _ch.invokeMethod('setInviteRotationPending', {'pending': pending});

  /// Clears Android-side local protection state (PIN flag, unlock window, native rules JSON,
  /// and usage counters). Use on logout so a new account starts clean.
  static Future<void> resetLocalProtectionState() =>
      _ch.invokeMethod('resetLocalProtectionState');

  static Future<bool> isInviteRotationPending() async {
    try {
      final v = await _ch.invokeMethod('isInviteRotationPending');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  /// Force the user out to the Android launcher (strict exit rule).
  static Future<void> goHome() => _ch.invokeMethod('goHome');

  static Future<void> setUsageLimitMinutes({
    required String packageName,
    required int minutes,
  }) =>
      _ch.invokeMethod('setUsageLimitMinutes', {
        'packageName': packageName,
        'minutes': minutes,
      });

  static Future<int> getUsageLimitMinutes(String packageName) async {
    try {
      return await _ch.invokeMethod('getUsageLimitMinutes', {
            'packageName': packageName,
          }) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getUsageTodayMinutes(String packageName) async {
    try {
      return await _ch.invokeMethod('getUsageTodayMinutes', {
            'packageName': packageName,
          }) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setFeatureUsageLimitMinutes({
    required String packageName,
    required String featureKey,
    required int minutes,
  }) =>
      _ch.invokeMethod('setFeatureUsageLimitMinutes', {
        'packageName': packageName,
        'featureKey': featureKey,
        'minutes': minutes,
      });

  static Future<int> getFeatureUsageLimitMinutes({
    required String packageName,
    required String featureKey,
  }) async {
    try {
      return await _ch.invokeMethod('getFeatureUsageLimitMinutes', {
            'packageName': packageName,
            'featureKey': featureKey,
          }) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getFeatureUsageTodayMinutes({
    required String packageName,
    required String featureKey,
  }) async {
    try {
      return await _ch.invokeMethod('getFeatureUsageTodayMinutes', {
            'packageName': packageName,
            'featureKey': featureKey,
          }) ??
          0;
    } catch (_) {
      return 0;
    }
  }
}
