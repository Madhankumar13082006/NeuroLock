import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/unlock_provider.dart';
import '../../platform/method_channel.dart';
import '../screens/pin_entry_screen.dart';

class ShellAppBarActions extends ConsumerWidget {
  const ShellAppBarActions({super.key});

  Future<void> _clearFlutterLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      // Feature toggles are stored as "<package>:<feature>"
      if (k.contains(':')) {
        await prefs.remove(k);
        continue;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'Sign out',
      onPressed: () async {
        final lock = ref.read(unlockProvider);
        if (lock.isPinSet) {
          final pin = await showDialog<String>(
            context: context,
            useRootNavigator: true,
            builder: (_) => const PinEntryDialog(
              title: 'Enter PIN to logout',
            ),
          );
          if (pin == null || pin.length != 4) return;
          final svc = ref.read(firebaseServiceProvider);
          final res = await svc.verifyPinIdentityLocalFirst(pin);
          if (!res.ok) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message ?? 'Invalid PIN'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }

          // After PIN verification, reset server state too so next login is fresh.
          try {
            await svc.clearUnlockExpiry();
          } catch (_) {}
          try {
            await svc.clearCurrentPin();
          } catch (_) {}
          try {
            await svc.clearAllBlocks();
          } catch (_) {}
          try {
            await svc.clearOfflinePinCache();
          } catch (_) {}
        }

        // Reset local-only state so a new login starts fresh.
        try {
          await PlatformBridge.resetLocalProtectionState();
        } catch (_) {}
        try {
          await _clearFlutterLocalState();
        } catch (_) {}
        await ref.read(authNotifierProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
    );
  }
}
