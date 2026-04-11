import 'package:flutter/services.dart';

class PlatformBridge {
  static const _ch = MethodChannel('com.impulsecontrol/bridge');
  static void Function(String route)? _onNavigate;

  /// Call once at app startup to receive navigation events from Android.
  static void initNavigation(void Function(String route) onNavigate) {
    _onNavigate = onNavigate;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final route = call.arguments as String?;
        if (route != null && route.isNotEmpty) {
          _onNavigate?.call(route);
        }
        return null;
      }
      return null;
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

  static Future<bool> isInviteRotationPending() async {
    try {
      final v = await _ch.invokeMethod('isInviteRotationPending');
      return v == true;
    } catch (_) {
      return false;
    }
  }
}
