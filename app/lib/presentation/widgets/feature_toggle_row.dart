import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../data/models/app_block_info.dart';
import '../../core/theme.dart';
import '../providers/block_provider.dart';
import '../../platform/method_channel.dart';
import '../providers/auth_provider.dart';
import '../providers/unlock_provider.dart';
import '../screens/pin_entry_screen.dart';

class FeatureToggleRow extends ConsumerWidget {
  final FeatureBlock feature;
  final String packageName;

  const FeatureToggleRow({
    super.key,
    required this.feature,
    required this.packageName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(blockProvider(packageName));
    final isOn = settings[feature.key] ?? false;
    final unlock = ref.watch(unlockProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(children: [
        // Icon
        Icon(
          feature.icon,
          color: isOn ? AppTheme.primary : AppTheme.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        // Label
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.label,
                  style: TextStyle(
                      color:
                          isOn ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15)),
            ],
          ),
        ),
        // Toggle
        Switch(
          value: isOn,
          onChanged: (_) async {
            final nextValue = !isOn;
            // When locked, prevent turning protection OFF without PIN.
            if (!nextValue && unlock.isPinSet && !unlock.isUnlocked) {
              final pin = await showDialog<String>(
                context: context,
                builder: (_) =>
                    const PinEntryDialog(title: 'Enter PIN to disable protection'),
              );
              if (pin == null) return;
              final ok = await ref.read(unlockProvider.notifier).unlockWithPin(pin);
              if (!ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid PIN'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }

            await ref
                .read(blockProvider(packageName).notifier)
                .toggle(feature.key);

            // Notify the native layer which apps should be blocked.
            // We block the whole app if any feature is enabled for it.
            try {
              final active = await BlockNotifier.getAllActiveBlocks();
              final packages = unlock.isPinSet
                  ? active.entries
                      .where((e) => e.value.isNotEmpty)
                      .map((e) => e.key)
                      .toList()
                  : <String>[];
              await PlatformBridge.setBlockedApps(packages);

              // If this toggle enabled a block, generate a shareable link immediately.
              final enabledNow =
                  (await BlockNotifier.getAllActiveBlocks())[packageName]
                          ?.contains(feature.key) ==
                      true;
              if (enabledNow) {
                final svc = ref.read(firebaseServiceProvider);
                final hasSetup = await svc.hasTrustedPinSetup();
                if (!hasSetup) {
                  final link = await svc.generateApprovalLink(
                    packageName: packageName,
                    blockedFeatures: active[packageName]?.toList() ?? const [],
                  );
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Trusted PIN setup link copied'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Show',
                          textColor: Colors.white,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppTheme.surface,
                                title: const Text('Share this setup link',
                                    style: TextStyle(color: AppTheme.textPrimary)),
                                content: SelectableText(link,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }
                }
              }
            } catch (_) {
              // Non-fatal (e.g. running on web/desktop).
            }
          },
        ),
      ]),
    );
  }
}
