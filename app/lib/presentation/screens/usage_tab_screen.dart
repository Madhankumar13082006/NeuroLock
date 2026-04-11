import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../widgets/shell_app_bar_actions.dart';

class UsageTabScreen extends ConsumerWidget {
  const UsageTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Usage'),
        actions: const [ShellAppBarActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Screen time overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect Usage Access in system settings to see real breakdowns. '
            'This tab is ready for live stats from the Usage Stats API.',
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), height: 1.45),
          ),
          const SizedBox(height: 24),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded, size: 48, color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text(
                    'Weekly chart placeholder',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
