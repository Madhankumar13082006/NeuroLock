import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../widgets/shell_app_bar_actions.dart';

class InboxTabScreen extends ConsumerWidget {
  const InboxTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: const [ShellAppBarActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: AppTheme.primary.withValues(alpha: 0.95)),
                    const SizedBox(width: 10),
                    Text(
                      'Invite links',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'When you turn on a block, NOKKON creates a one-time link. '
                  'Someone you trust opens it in a browser and sets a 4-digit PIN. '
                  'You will not be able to open that link on this device—ask them to use their phone.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.95),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tip: use the menu (☰) on the In-App tab if you need to turn on '
                  'Android accessibility so the lock screen can appear over other apps.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.75),
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
                const SizedBox(height: 12),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
