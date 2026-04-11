import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/firebase_service.dart';
import 'auth_provider.dart';

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

    // Remote (Firestore)
    for (final k in data.keys) {
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
          result.putIfAbsent(parts[0], () => {}).add(parts[1]);
        }
      }
    }
    return result;
  }
}

final blockProvider =
    StateNotifierProvider.family<BlockNotifier, Map<String, bool>, String>(
  (ref, pkg) => BlockNotifier(pkg, ref.watch(firebaseServiceProvider)),
);
