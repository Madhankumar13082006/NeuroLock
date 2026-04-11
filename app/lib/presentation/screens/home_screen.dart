import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/block_provider.dart';
import '../providers/unlock_provider.dart';
import '../widgets/app_usage_chart.dart';
import '../widgets/feature_toggle_row.dart';
import '../widgets/invite_link_flow.dart';
import '../widgets/shell_app_bar_actions.dart';
import '../../platform/method_channel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _expanded = {};
  final TextEditingController _search = TextEditingController();
  final Map<String, Uint8List> _icons = {};

  @override
  void initState() {
    super.initState();
    _syncNativeBlockedApps();
    _loadInstalledIcons();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
              'Screen monitoring',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'To show the lock screen when you open YouTube, Instagram, or '
              'Snapchat, turn on NOKKON under Accessibility in Android settings. '
              'You can change this anytime.',
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
          'Reels': 8.0,
          'Stories': 6.0,
          'Feed': 34.0,
        };
      case 'com.instagram.android':
        return const {
          'Shorts': 5.0,
          'Reels': 48.0,
          'Stories': 22.0,
          'Feed': 25.0,
        };
      case 'com.snapchat.android':
        return const {
          'Shorts': 18.0,
          'Reels': 12.0,
          'Stories': 35.0,
          'Feed': 35.0,
        };
      default:
        return const {'Other': 100.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UnlockState>(unlockProvider, (_, __) {
      _syncNativeBlockedApps();
    });

    final lock = ref.watch(unlockProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded,
                  size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            const Text('NOKKON'),
          ],
        ),
        actions: const [ShellAppBarActions()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textSecondary,
                  ),
                  onPressed: () => _showBlockingHelp(context),
                  tooltip: 'Blocking help',
                  icon: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search in NOKKON',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.75),
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        size: 22,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.notifications_none_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!lock.isPinSet)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Blocking runs in the background. Confirm a block, then share a one-time link if you want a trusted PIN.',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 8),
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
          // Shown whether the card is collapsed OR expanded — users should
          // never have to hunt for this button after enabling a block.
          if (nActive > 0) ...[
            Divider(
              color: AppTheme.cardBorder.withValues(alpha: 0.5),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      InviteLinkFlow.generateInviteLinkWithOptionalPin(
                    context,
                    ref,
                    packageName: app.packageName,
                  ),
                  icon: const Icon(Icons.link_rounded, size: 20),
                  label: Text(
                    isPinSet ? 'Generate new invite link' : 'Generate invite link',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Text(
                isPinSet
                    ? 'Enter your current PIN first. The old PIN is removed; the next person to open the new link sets a fresh PIN.'
                    : 'One-time link — first person to open it sets the PIN; link then stops working.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
