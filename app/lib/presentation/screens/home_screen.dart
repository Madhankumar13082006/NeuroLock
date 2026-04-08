import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:installed_apps/installed_apps.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/block_provider.dart';
import '../providers/unlock_provider.dart';
import '../widgets/app_usage_chart.dart';
import '../widgets/feature_toggle_row.dart';
import '../../platform/method_channel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expanded = {};
  bool _accessibilityEnabled = false;
  final Map<String, Uint8List> _icons = {};

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
    _syncNativeBlockedApps();
    _loadInstalledIcons();
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PlatformBridge.isAccessibilityEnabled();
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  Future<void> _syncNativeBlockedApps() async {
    try {
      final lock = ref.read(unlockProvider);
      final active = await BlockNotifier.getAllActiveBlocks();
      final packages = lock.isPinSet
          ? active.entries.where((e) => e.value.isNotEmpty).map((e) => e.key)
          : <String>[];
      await PlatformBridge.setBlockedApps(packages.toList());
    } catch (_) {
      // Non-fatal: native bridge might not exist on some platforms.
    }
  }

  Future<void> _loadInstalledIcons() async {
    try {
      for (final app in kSupportedApps) {
        final info = await InstalledApps.getAppInfo(app.packageName);
        final icon = info?.icon;
        if (icon != null) {
          _icons[app.packageName] = icon;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Non-fatal (plugin may not work on emulator/desktop).
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(unlockProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_rounded,
                size: 20, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          const Text('Nokkon'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            tooltip: 'Trusted Contacts',
            onPressed: () => context.push('/home/contacts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Accessibility status bar
          if (!_accessibilityEnabled)
            GestureDetector(
              onTap: () async {
                await PlatformBridge.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 2));
                _checkAccessibility();
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2500),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accessibility service is OFF — tap to enable app blocking',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.orange),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          // Top tabs (matching StayFree layout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _TabChip(label: 'In-App Blocks', selected: true),
            ]),
          ),
          const SizedBox(height: 12),
          // App list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: kSupportedApps.length,
              itemBuilder: (ctx, i) {
                final app = kSupportedApps[i];
                final isExpanded = _expanded.contains(app.packageName);
                return _AppCard(
                  app: app,
                  isExpanded: isExpanded,
                  iconBytes: _icons[app.packageName],
                  isPinSet: lock.isPinSet,
                  onToggleExpand: () {
                    setState(() {
                      if (isExpanded) {
                        _expanded.remove(app.packageName);
                      } else {
                        _expanded.add(app.packageName);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _TabChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13)),
    );
  }
}

class _AppCard extends ConsumerWidget {
  final SupportedApp app;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Uint8List? iconBytes;
  final bool isPinSet;

  const _AppCard({
    required this.app,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.iconBytes,
    required this.isPinSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(blockProvider(app.packageName));
    final anyEnabled = settings.values.any((v) => v);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                // App icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: app.brandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: iconBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            iconBytes!,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.apps, size: 24, color: app.brandColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.displayName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      if (anyEnabled)
                        Text(
                          isPinSet
                              ? '${settings.values.where((v) => v).length} block(s) active'
                              : 'Waiting for trusted person to set PIN',
                          style: TextStyle(
                              color: isPinSet
                                  ? AppTheme.primary
                                  : const Color(0xFFFBBF24),
                              fontSize: 12),
                        )
                      else
                        const Text('No blocks active',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                ),
              ]),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            // Usage chart
            AppUsageChart(
              usageData: _getMockUsage(app.packageName),
              appColor: app.brandColor,
            ),
            const Divider(color: Color(0xFF2E2E45), height: 1),
            // Feature toggles
            ...app.features.map((feature) => FeatureToggleRow(
                  feature: feature,
                  packageName: app.packageName,
                )),

            // Generate Link Button (if any blocks active)
            // TODO: Fix button implementation
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Map<String, double> _getMockUsage(String packageName) {
    if (packageName == 'com.google.android.youtube') {
      return {
        'Shorts': 88.6,
        'Search': 3.7,
        'Pip': 1.2,
        'Comments': 0.9,
        'Other': 5.6,
      };
    }
    if (packageName == 'com.instagram.android') {
      return {
        'Reels': 72.4,
        'Explore': 14.2,
        'Stories': 8.1,
        'Other': 5.3,
      };
    }
    return {'Usage': 100.0};
  }
}
