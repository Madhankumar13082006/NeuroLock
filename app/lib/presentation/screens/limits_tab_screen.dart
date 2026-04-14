import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../widgets/shell_app_bar_actions.dart';

class LimitsTabScreen extends ConsumerWidget {
  const LimitsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Daily limits'),
        actions: const [ShellAppBarActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Section title ────────────────────────────────────────
          Text(
            'Daily caps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set how many minutes per day you want to allow for each app or feature. '
            'Blocking kicks in automatically when the limit is reached.',
            style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                height: 1.45,
                fontSize: 14),
          ),
          const SizedBox(height: 20),

          // ── App rows ─────────────────────────────────────────────
          ...['YouTube', 'Instagram', 'Snapchat'].map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.timer_outlined,
                          color: AppTheme.primary.withValues(alpha: 0.9),
                          size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Set limit',
                        style: TextStyle(
                          color: AppTheme.primary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
