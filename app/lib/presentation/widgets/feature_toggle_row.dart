import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/block_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/unlock_provider.dart';
import '../screens/pin_entry_screen.dart';
import 'invite_link_flow.dart';
import '../../platform/method_channel.dart';

class FeatureToggleRow extends ConsumerStatefulWidget {
  final FeatureBlock feature;
  final String packageName;
  final String appDisplayName;

  const FeatureToggleRow({
    super.key,
    required this.feature,
    required this.packageName,
    required this.appDisplayName,
  });

  @override
  ConsumerState<FeatureToggleRow> createState() => _FeatureToggleRowState();
}

class _FeatureToggleRowState extends ConsumerState<FeatureToggleRow> {
  int _limitMin = 0;
  int _spentMin = 0;
  bool _loadingUsage = true;
  int _featureLimitMin = 0;
  int _featureSpentMin = 0;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  Future<void> _refreshUsage() async {
    setState(() => _loadingUsage = true);
    final limit = await PlatformBridge.getUsageLimitMinutes(widget.packageName);
    final spent = await PlatformBridge.getUsageTodayMinutes(widget.packageName);
    var featureLimit = await PlatformBridge.getFeatureUsageLimitMinutes(
      packageName: widget.packageName,
      featureKey: widget.feature.key,
    );
    if (_isTimedFeature && featureLimit <= 0) {
      try {
        final blocks =
            await ref.read(firebaseServiceProvider).getBlocks(widget.packageName);
        final remoteLimit = (blocks['${widget.feature.key}_limit_minutes'] as num?)
                ?.toInt() ??
            0;
        if (remoteLimit > 0) {
          await PlatformBridge.setFeatureUsageLimitMinutes(
            packageName: widget.packageName,
            featureKey: widget.feature.key,
            minutes: remoteLimit,
          );
          featureLimit = remoteLimit;
        }
      } catch (_) {}
    }
    final featureSpent = await PlatformBridge.getFeatureUsageTodayMinutes(
      packageName: widget.packageName,
      featureKey: widget.feature.key,
    );
    if (!mounted) return;
    setState(() {
      _limitMin = limit;
      _spentMin = spent;
      _featureLimitMin = featureLimit;
      _featureSpentMin = featureSpent;
      _loadingUsage = false;
    });
  }

  bool get _isTimedFeature =>
      (widget.packageName == 'com.google.android.youtube' &&
          (widget.feature.key == 'shorts' ||
              widget.feature.key == 'web_shorts')) ||
      (widget.packageName == 'com.instagram.android' &&
          (widget.feature.key == 'reels' ||
              widget.feature.key == 'web_reels' ||
              widget.feature.key == 'explore'));

  Future<int?> _pickTimedFeatureLimit(BuildContext context) async {
    final presets = <int>[0, 5, 10, 15, 20, 30, 45, 60, 90, 120];
    return showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Allow minutes before block',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in presets)
                ListTile(
                  title: Text(
                    m == 0 ? '0 minutes (Off)' : '$m minutes',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLimit(BuildContext context) async {
    final presets = <int>[0, 5, 10, 15, 30, 45, 60, 90, 120];
    final chosen = await showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Usage Limit Time',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in presets)
                ListTile(
                  title: Text(
                    m == 0 ? '0m (Off)' : '${m}m',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await PlatformBridge.setUsageLimitMinutes(
      packageName: widget.packageName,
      minutes: chosen,
    );
    await _refreshUsage();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(blockProvider(widget.packageName));
    final isOn = settings[widget.feature.key] ?? false;
    final unlock = ref.watch(unlockProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              widget.feature.icon,
              color: isOn ? AppTheme.primary : AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      widget.feature.label,
                      style: TextStyle(
                        color: isOn
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.feature.earlyAccess)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4A9EFF).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Early Access',
                          style: TextStyle(
                            color: Color(0xFF7EC8FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    ),
                    children: [
                      const TextSpan(text: 'Daily usage limit: '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => _pickLimit(context),
                          child: Text(
                            _loadingUsage ? '…' : '${_limitMin}m',
                            style: TextStyle(
                              color: AppTheme.primary.withValues(alpha: 0.95),
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  AppTheme.primary.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                if (_isTimedFeature)
                  Text(
                    _loadingUsage
                        ? 'Shorts/Reels allowance: …'
                        : 'Allow before block: ${_featureLimitMin}m · Used today: ${_featureSpentMin}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                if (_isTimedFeature) const SizedBox(height: 2),
                Text(
                  _loadingUsage
                      ? 'Time spent today: …'
                      : 'Time spent today: ${_spentMin}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: (_) async {
              final nextValue = !isOn;

              // Once a trusted PIN is set, blocks become immutable.
              // User must remove PIN, change blocks, then generate a fresh link.
              if (unlock.isPinSet) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Blocks are locked while PIN is active. Remove PIN to change blocks, then generate a new invite link.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              // ── Turning ON: confirm dialog ────────────────────────────────
              if (nextValue) {
                final accessibilityEnabled =
                    await PlatformBridge.isAccessibilityEnabled();
                if (!accessibilityEnabled) {
                  if (!context.mounted) return;
                  final openSettings = await showDialog<bool>(
                    context: context,
                    useRootNavigator: true,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text(
                        'Enable Accessibility first',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      content: const Text(
                        'Protection can be turned on only after Accessibility is enabled for NeuroLock.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Open settings'),
                        ),
                      ],
                    ),
                  );
                  if (openSettings == true) {
                    await PlatformBridge.openAccessibilitySettings();
                  }
                  return;
                }

                final confirmed = await InviteLinkFlow.showConfirmBlockDialog(
                  context,
                  featureLabel: widget.feature.label,
                  appDisplayName: widget.appDisplayName,
                );
                if (!confirmed || !context.mounted) return;
                if (_isTimedFeature) {
                  final minutes = await _pickTimedFeatureLimit(context);
                  if (minutes == null || !context.mounted) return;
                  await PlatformBridge.setFeatureUsageLimitMinutes(
                    packageName: widget.packageName,
                    featureKey: widget.feature.key,
                    minutes: minutes,
                  );
                  await ref
                      .read(firebaseServiceProvider)
                      .saveFeatureUsageLimitMinutes(
                        widget.packageName,
                        widget.feature.key,
                        minutes,
                      );
                }
              }

              // ── Turning OFF: require PIN ──────────────────────────────────
              if (!nextValue && unlock.isPinSet && !unlock.isUnlocked) {
                final pin = await showDialog<String>(
                  context: context,
                  builder: (_) => const PinEntryDialog(
                    title: 'Enter PIN to disable protection',
                  ),
                );
                if (pin == null) return;
                final pinErr =
                    await ref.read(unlockProvider.notifier).unlockWithPin(pin);
                if (pinErr != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(pinErr),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
              }

              // ── Save the block ────────────────────────────────────────────
              try {
                await ref
                    .read(blockProvider(widget.packageName).notifier)
                    .toggle(widget.feature.key);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not save: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              if (!context.mounted) return;

              // Non-critical native sync — wrapped so any method-channel error
              // never silently prevents the link screen from opening below.
              try {
                await BlockNotifier.syncNativeBlockConfig(
                    ref.read(unlockProvider));
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }
}
