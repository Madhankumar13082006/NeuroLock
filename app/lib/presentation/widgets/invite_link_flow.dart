import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_list.dart';
import '../../core/theme.dart';
import '../../platform/method_channel.dart';
import '../providers/auth_provider.dart';
import '../providers/block_provider.dart';
import '../providers/unlock_provider.dart';
import '../screens/link_generated_screen.dart';
import '../screens/pin_entry_screen.dart';

/// Confirm blocking, then optionally generate a one-time invite link.
class InviteLinkFlow {
  InviteLinkFlow._();

  static Future<bool> showConfirmBlockDialog(
    BuildContext context, {
    required String featureLabel,
    required String appDisplayName,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Block this feature?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'You are about to block $featureLabel on $appDisplayName.\n\n'
          'After you confirm, you can create a one-time invite link so someone '
          'you trust can set the unlock PIN. Anyone who opens that link can set '
          'the PIN only once; then the link stops working.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            height: 1.45,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm block'),
          ),
        ],
      ),
    );
    return go == true;
  }

  /// Returns true if user wants to generate a link now.
  static Future<bool> showAskGenerateLinkDialog(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Generate invite link?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'If you tap Generate link, we create a single-use link. '
          'Share it by WhatsApp, email, or any app—whoever opens it first can set '
          'the 4-digit PIN one time only. After that, the link no longer works.\n\n'
          'You can create a link later from this app card if you tap Not now.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.45,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate link'),
          ),
        ],
      ),
    );
    return go == true;
  }

  /// Opens the link screen. If a trusted PIN already exists, asks for that PIN
  /// first, clears it server-side, and keeps native rules armed until the new
  /// PIN is set from the fresh invite link.
  static Future<void> generateInviteLinkWithOptionalPin(
    BuildContext context,
    WidgetRef ref, {
    required String packageName,
  }) async {
    final lock = ref.read(unlockProvider);
    if (!lock.isPinSet) {
      await generateAndShowInviteScreen(context, ref, packageName: packageName);
      return;
    }
    if (!context.mounted) return;
    final pin = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const PinEntryDialog(
        title: 'Enter current PIN to create a new invite link',
      ),
    );
    if (pin == null || !context.mounted) return;

    final svc = ref.read(firebaseServiceProvider);
    final res = await svc.verifyPinIdentityOnly(pin);
    if (!res.ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Could not verify PIN'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // verify-pin may still grant a temporary unlock on the server; drop it
    // here since we only needed proof of PIN for a new invite link.
    try {
      await svc.clearUnlockExpiry();
    } catch (_) {}

    try {
      await PlatformBridge.setInviteRotationPending(true);
      await svc.clearCurrentPin();
    } catch (e) {
      await PlatformBridge.setInviteRotationPending(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not reset PIN for new link: ${e.toString().split(']').last.trim()}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    try {
      await BlockNotifier.syncNativeBlockConfig(ref.read(unlockProvider));
    } catch (_) {}
    if (!context.mounted) return;
    await generateAndShowInviteScreen(context, ref, packageName: packageName);
  }

  /// Creates a new approval_links doc and opens the share screen.
  ///
  /// Reads active features from [blockProvider] Riverpod state (set
  /// synchronously by toggle()) instead of SharedPreferences, which avoids
  /// a timing race where the Firestore write hasn't flushed yet.
  static Future<void> generateAndShowInviteScreen(
    BuildContext context,
    WidgetRef ref, {
    required String packageName,
  }) async {
    // Global PIN: generate one link for the whole account.
    // Read active blocks from Riverpod state so behavior reflects current UI
    // immediately (without stale local cache).
    final active = <String, Set<String>>{};
    for (final app in kSupportedApps) {
      final state = ref.read(blockProvider(app.packageName));
      final enabled = state.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();
      if (enabled.isNotEmpty) {
        active[app.packageName] = enabled;
      }
    }

    // Fallback for sessions where providers are not yet warmed.
    if (active.isEmpty) {
      final fromPrefs = await BlockNotifier.getAllActiveBlocks();
      active.addAll(fromPrefs);
    }

    final feats = <String>[];
    for (final e in active.entries) {
      for (final f in e.value) {
        feats.add('${e.key}:$f');
      }
    }

    if (feats.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turn on at least one block for this app first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final svc = ref.read(firebaseServiceProvider);
    try {
      final link = await svc.generateApprovalLink(
        // The server pin is global (lock_state/main.currentPIN). Use a constant
        // package label for invite metadata.
        packageName: 'global',
        blockedFeatures: feats,
      );
      if (!context.mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => LinkGeneratedScreen(link: link),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not create link: ${e.toString().split(']').last.trim()}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
