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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final Set<String> _expanded = {};
  bool _accessibilityEnabled = false;
  bool _accessibilityChecked = false;
  final Map<String, Uint8List> _icons = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibility();
    _syncNativeBlockedApps();
    _loadInstalledIcons();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check accessibility every time the user returns to the app —
    // they might have just enabled it from the system settings.
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PlatformBridge.isAccessibilityEnabled();
    if (!mounted) return;
    setState(() {
      _accessibilityEnabled = enabled;
      _accessibilityChecked = true;
    });
  }

  Future<void> _syncNativeBlockedApps() async {
    try {
      final lock = ref.read(unlockProvider);
      final active = await BlockNotifier.getAllActiveBlocks();
      final packages = lock.isPinSet
          ? active.entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => e.key)
              .toList()
          : <String>[];
      await PlatformBridge.setBlockedApps(packages);
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

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(unlockProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.glow(AppTheme.primary, opacity: 0.28),
              ),
              child: const Icon(Icons.shield_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Nokkon'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded),
            tooltip: 'Trusted contacts',
            onPressed: () => context.push('/home/contacts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sticky accessibility prompt — always visible if disabled.
            if (_accessibilityChecked && !_accessibilityEnabled)
              _AccessibilityPrompt(
                onTap: () async {
                  await PlatformBridge.openAccessibilitySettings();
                  // Give Android a beat to switch the toggle, then re-check.
                  await Future<void>.delayed(const Duration(seconds: 2));
                  if (!mounted) return;
                  await _checkAccessibility();
                },
              ),
            // Status banner showing PIN/lock state.
            _StatusCard(lock: lock),
            const SizedBox(height: 4),
            // App list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
      ),
    );
  }
}

/// Sticky orange/amber bar that appears when the Android accessibility
/// service isn't enabled. Tapping opens system settings.
class _AccessibilityPrompt extends StatelessWidget {
  final Future<void> Function() onTap;
  const _AccessibilityPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1B00),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.warning.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Accessibility service is OFF',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to enable so Nokkon can block apps.',
                      style: TextStyle(
                        color: Color(0xFFD2BA77),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top status banner that summarises the lock state for the user.
class _StatusCard extends StatelessWidget {
  final UnlockState lock;
  const _StatusCard({required this.lock});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final Color color;
    final IconData icon;

    if (lock.isUnlocked) {
      final mins = lock.remaining.inMinutes;
      title = 'Temporarily unlocked';
      subtitle = mins > 0
          ? '$mins min remaining before re-lock'
          : 'Less than a minute left';
      color = AppTheme.warning;
      icon = Icons.lock_open_rounded;
    } else if (lock.isPinSet) {
      title = 'Protection active';
      subtitle = 'Your trusted person controls the PIN';
      color = AppTheme.success;
      icon = Icons.verified_user_rounded;
    } else {
      title = 'No PIN set up yet';
      subtitle = 'Toggle a feature to share a setup link';
      color = AppTheme.primarySoft;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final activeCount = settings.values.where((v) => v).length;
    final anyEnabled = activeCount > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: anyEnabled
              ? app.brandColor.withValues(alpha: 0.45)
              : AppTheme.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Header row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: app.brandColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: iconBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(
                                iconBytes!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.apps_rounded,
                              size: 24, color: app.brandColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.displayName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            anyEnabled
                                ? (isPinSet
                                    ? '$activeCount block${activeCount == 1 ? '' : 's'} active'
                                    : 'Waiting for trusted PIN')
                                : 'No blocks active',
                            style: TextStyle(
                              color: anyEnabled
                                  ? (isPinSet
                                      ? AppTheme.primarySoft
                                      : AppTheme.warning)
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Expanded content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                AppUsageChart(
                  usageData: _getMockUsage(app.packageName),
                  appColor: app.brandColor,
                ),
                const Divider(color: AppTheme.divider, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: app.features
                        .map(
                          (feature) => FeatureToggleRow(
                            feature: feature,
                            packageName: app.packageName,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
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
