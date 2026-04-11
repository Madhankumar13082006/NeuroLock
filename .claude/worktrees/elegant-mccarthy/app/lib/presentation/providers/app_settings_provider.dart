import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local settings provider — no backend needed
class AppSettingsNotifier extends StateNotifier<Map<String, bool>> {
  final String packageName;
  late SharedPreferences _prefs;

  AppSettingsNotifier(this.packageName) : super({}) {
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final keys = _prefs.getKeys().where((k) => k.startsWith('$packageName:'));
    final Map<String, bool> loaded = {};
    for (final k in keys) {
      loaded[k.replaceFirst('$packageName:', '')] = _prefs.getBool(k) ?? false;
    }
    state = loaded;
  }

  Future<void> toggle(String featureKey) async {
    _prefs = await SharedPreferences.getInstance();
    final current = state[featureKey] ?? false;
    final updated = Map<String, bool>.from(state);
    updated[featureKey] = !current;
    await _prefs.setBool('$packageName:$featureKey', !current);
    state = updated;
  }

  bool get(String featureKey) => state[featureKey] ?? false;

  // Returns all packages that have block_all = true
  static Future<Set<String>> getFullyBlockedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = <String>{};
    for (final k in prefs.getKeys()) {
      if (k.endsWith(':block_all') && prefs.getBool(k) == true) {
        blocked.add(k.replaceAll(':block_all', ''));
      }
    }
    return blocked;
  }
}

// Family provider — one per app
final appSettingsProvider = StateNotifierProvider.family(
  (ref, String packageName) => AppSettingsNotifier(packageName),
);
