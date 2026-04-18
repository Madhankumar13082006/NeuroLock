import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/block_provider.dart';
import '../providers/unlock_provider.dart';
import '../widgets/app_usage_chart.dart';
import '../widgets/feature_toggle_row.dart';
import '../widgets/invite_link_flow.dart';
import '../widgets/brand_logo.dart';
import '../widgets/shell_app_bar_actions.dart';
import '../../platform/method_channel.dart';
import 'pin_entry_screen.dart';
import 'accessibility_permission_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expanded = {};
  final TextEditingController _search = TextEditingController();
  final Map<String, Uint8List> _icons = {};
  bool _askedAccessibility = false;

  @override
  void initState() {
    super.initState();
    _syncNativeBlockedApps();
    _loadInstalledIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkOnboarding();
      if (mounted) _ensureAccessibilityEnabled();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureAccessibilityEnabled();
  }

  // Pushes to onboarding on first launch; no-op after onboarding_done is set.
  Future<void> _checkOnboarding() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('onboarding_done') ?? false) && mounted) {
      context.push('/onboarding');
    }
  }

  Future<void> _ensureAccessibilityEnabled() async {
    if (!mounted) return;
    if (_askedAccessibility) return;
    // Onboarding handles accessibility setup on first launch — skip until done.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('onboarding_done') ?? false)) return;
    final enabled = await PlatformBridge.isAccessibilityEnabled();
    if (!mounted || enabled) return;
    _askedAccessibility = true;
    await showAccessibilityPermissionSheet(context);
    if (!mounted) return;
    _askedAccessibility = false;
  }

  Future<void> _syncNativeBlockedApps() async {
    try {
      final lock = ref.read(unlockProvider);
      await BlockNotifier.syncNativeBlockConfig(lock);
    } catch (_) {}
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
    } catch (_) {}
  }

  List<SupportedApp> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return kSupportedApps;
    return kSupportedApps
        .where((a) => a.displayName.toLowerCase().contains(q))
        .toList();
  }

  void _showBlockingHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How NeuroLock works',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              '1) Turn on a block (YouTube Shorts or Instagram Reels).\n'
              '2) Tap Generate link and send it to a trusted person.\n'
              '3) Your trusted person opens the link once and sets a 4-digit PIN.\n'
              '4) From then on, blocked features stay locked until you enter the PIN.\n\n'
              'Important: Do not open the invite link on this phone. The first opener sets the PIN and the link becomes invalid.',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.95),
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  PlatformBridge.openAccessibilitySettings();
                },
                child: const Text('Open accessibility settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _usageFor(SupportedApp app) {
    switch (app.packageName) {
      case 'com.google.android.youtube':
        return const {
          'Shorts': 52.0,
        };
      case 'com.instagram.android':
        return const {
          'Reels': 48.0,
        };
      default:
        return const {'Other': 100.0};
    }
  }

  Future<void> _generateGlobalInviteLink(BuildContext context) async {
    await InviteLinkFlow.generateInviteLinkWithOptionalPin(
      context,
      ref,
      packageName: 'global',
    );
    // Rotation flag is now set — arm native blocks immediately so they're
    // ready the instant the trusted person sets the PIN remotely.
    if (mounted) _syncNativeBlockedApps();
  }

  Future<void> _removeGlobalPin(BuildContext context) async {
    final pin = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const PinEntryDialog(
        title: 'Enter PIN to remove it',
      ),
    );
    if (pin == null || !context.mounted) return;
    final err = await ref.read(unlockProvider.notifier).removeTrustedPin(pin);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN removed. All protections are now OFF.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    for (final app in kSupportedApps) {
      ref.invalidate(blockProvider(app.packageName));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass `next` directly — avoids re-reading stale state when PIN is first set.
    ref.listen<UnlockState>(unlockProvider, (_, next) {
      BlockNotifier.syncNativeBlockConfig(next).catchError((_) {});
    });

    final lock = ref.watch(unlockProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            const BrandLogo(size: 32, radius: 8),
            const SizedBox(width: 10),
            const Text('NeuroLock'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 22),
            color: AppTheme.textSecondary,
            tooltip: 'Accessibility setup',
            onPressed: () => _showBlockingHelp(context),
          ),
          const ShellAppBarActions(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x337C8CFF), Color(0x334CA4FF)],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
            ),
            child: const Text(
              'Stay focused today. Set blocks you need and keep distractions out.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search apps',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.65),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  size: 22,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!lock.isPinSet)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.primary.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Toggle a block below, then share the invite link with a trusted person to set your PIN.',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: lock.isPinSet
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _generateGlobalInviteLink(context),
                          icon: const Icon(Icons.link_rounded, size: 20),
                          label: const Text('New invite link'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _removeGlobalPin(context),
                          icon: const Icon(Icons.delete_forever_rounded,
                              size: 20),
                          label: const Text('Remove PIN'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: BorderSide(
                              color: AppTheme.danger.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _generateGlobalInviteLink(context),
                      icon: const Icon(Icons.link_rounded, size: 20),
                      label: const Text('Generate invite link'),
                    ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final app = _filtered[i];
                final isExpanded = _expanded.contains(app.packageName);
                return _AppCard(
                  app: app,
                  isExpanded: isExpanded,
                  iconBytes: _icons[app.packageName],
                  isPinSet: lock.isPinSet,
                  usageData: _usageFor(app),
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

class _AppCard extends ConsumerWidget {
  final SupportedApp app;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Uint8List? iconBytes;
  final bool isPinSet;
  final Map<String, double> usageData;

  const _AppCard({
    required this.app,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.iconBytes,
    required this.isPinSet,
    required this.usageData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(blockProvider(app.packageName));
    final nActive = settings.values.where((v) => v).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: app.brandColor.withValues(alpha: 0.12),
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
                        Text(
                          nActive > 0
                              ? '${app.displayName} ($nActive)'
                              : app.displayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (nActive > 0)
                          Text(
                            isPinSet
                                ? 'Protection active'
                                : 'Waiting for trusted PIN via invite link',
                            style: TextStyle(
                              color: isPinSet
                                  ? AppTheme.primary.withValues(alpha: 0.95)
                                  : AppTheme.amber.withValues(alpha: 0.95),
                              fontSize: 12,
                            ),
                          )
                        else
                          Text(
                            'No blocks enabled',
                            style: TextStyle(
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            AppUsageChart(
              usageData: usageData,
            ),
            Divider(
              color: AppTheme.cardBorder.withValues(alpha: 0.8),
              height: 1,
            ),
            ...app.features.map(
              (feature) => FeatureToggleRow(
                feature: feature,
                packageName: app.packageName,
                appDisplayName: app.displayName,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
