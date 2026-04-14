import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/app_block_info.dart';
import '../../data/services/firebase_service.dart';
import '../../platform/method_channel.dart';
import 'auth_provider.dart';
import 'unlock_provider.dart';

class BlockNotifier extends StateNotifier<Map<String, bool>> {
  final String packageName;
  final FirebaseService _svc;

  BlockNotifier(this.packageName, this._svc) : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await _svc.getBlocks(packageName);
    final Map<String, bool> merged = {};
    final allowed = _allowedFeatureKeysForPackage(packageName);

    // Remote (Firestore)
    for (final k in data.keys) {
      if (!allowed.contains(k)) continue;
      final v = data[k];
      if (v is bool) {
        merged[k] = v;
      } else if (v is num) {
        merged[k] = v != 0;
      } else if (v is String) {
        merged[k] = v.toLowerCase() == 'true';
      }
    }

    // Local (SharedPreferences) fallback / offline support.
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('$packageName:')) continue;
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final featureKey = parts[1];
      if (!allowed.contains(featureKey)) continue;
      merged.putIfAbsent(featureKey, () => prefs.getBool(key) ?? false);
    }

    state = merged;
  }

  bool isEnabled(String key) => state[key] ?? false;

  Future<void> toggle(String key) async {
    final next = !(state[key] ?? false);
    state = {...state, key: next};
    await _svc.saveFeatureBlock(packageName, key, next);

    // Sync to SharedPreferences for native layer
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$packageName:$key', next);
  }

  List<String> get activeBlocks =>
      state.entries.where((e) => e.value).map((e) => e.key).toList();

  static Future<Map<String, Set<String>>> getAllActiveBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Set<String>> result = {};
    for (final k in prefs.getKeys()) {
      if (prefs.getBool(k) == true) {
        final parts = k.split(':');
        if (parts.length == 2) {
          final pkg = parts[0];
          final feature = parts[1];
          if (!_allowedFeatureKeysForPackage(pkg).contains(feature)) continue;
          result.putIfAbsent(pkg, () => {}).add(feature);
        }
      }
    }
    return result;
  }

  static Set<String> _allowedFeatureKeysForPackage(String pkg) {
    for (final a in kSupportedApps) {
      if (a.packageName == pkg) {
        return a.features.map((f) => f.key).toSet();
      }
    }
    return const <String>{};
  }

  /// Pushes per-app feature rules to Android (Shorts-only vs whole app, etc.).
  static Future<void> syncNativeBlockConfig(UnlockState lock) async {
    final rotation = await PlatformBridge.isInviteRotationPending();
    if (!lock.isPinSet && !rotation) {
      await PlatformBridge.setBlockConfig('{}');
      return;
    }
    final active = await getAllActiveBlocks();
    if (active.isEmpty) {
      await PlatformBridge.setBlockConfig('{}');
      return;
    }
    final jsonMap = <String, dynamic>{
      for (final e in active.entries) e.key: e.value.toList(),
    };
    await PlatformBridge.setBlockConfig(jsonEncode(jsonMap));
  }
}

final blockProvider =
    StateNotifierProvider.family<BlockNotifier, Map<String, bool>, String>(
  (ref, pkg) => BlockNotifier(pkg, ref.watch(firebaseServiceProvider)),
);
