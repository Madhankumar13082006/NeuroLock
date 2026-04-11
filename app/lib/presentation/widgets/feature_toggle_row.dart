import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/block_provider.dart';
import '../providers/unlock_provider.dart';
import '../screens/pin_entry_screen.dart';
import 'invite_link_flow.dart';

class FeatureToggleRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(blockProvider(packageName));
    final isOn = settings[feature.key] ?? false;
    final unlock = ref.watch(unlockProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              feature.icon,
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
                      feature.label,
                      style: TextStyle(
                        color: isOn
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (feature.earlyAccess)
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
                          onTap: () {},
                          child: Text(
                            '0m',
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
                Text(
                  'Time spent today: 0m',
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

              // Capture BEFORE any awaits — a Firestore stream update arriving
              // during the operation must not change which branch we take.
              final pinSetAtToggleTime = unlock.isPinSet;

              // ── Turning ON: confirm dialog ────────────────────────────────
              if (nextValue) {
                final confirmed = await InviteLinkFlow.showConfirmBlockDialog(
                  context,
                  featureLabel: feature.label,
                  appDisplayName: appDisplayName,
                );
                if (!confirmed || !context.mounted) return;
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
                    .read(blockProvider(packageName).notifier)
                    .toggle(feature.key);
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

              if (!context.mounted) return;

              // ── Auto-generate invite link ─────────────────────────────────
              // Use pinSetAtToggleTime so a Firestore stream update that arrives
              // during the awaits above cannot flip this to true and skip the
              // link screen (the #1 cause of “link never appears” reports).
              if (nextValue && !pinSetAtToggleTime) {
                await InviteLinkFlow.generateAndShowInviteScreen(
                  context,
                  ref,
                  packageName: packageName,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
