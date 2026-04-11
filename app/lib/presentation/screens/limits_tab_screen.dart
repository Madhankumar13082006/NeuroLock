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
        title: const Text('Usage limits'),
        actions: const [ShellAppBarActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Daily caps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Per-feature daily limits will mirror the StayFree-style rows on the '
            'In-App tab. Wire this to your backend when limits are stored server-side.',
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), height: 1.45),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: AppTheme.primary.withValues(alpha: 0.9)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        ['YouTube', 'Instagram', 'Snapchat'][i],
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'Set limit',
                      style: TextStyle(
                        color: AppTheme.primary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
