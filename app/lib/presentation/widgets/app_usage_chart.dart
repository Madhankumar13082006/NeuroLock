import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AppUsageChart extends StatelessWidget {
  final Map<String, double> usageData;

  const AppUsageChart({
    super.key,
    required this.usageData,
  });

  static const _colors = [
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = usageData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entries = sorted;

    final top = entries.isNotEmpty ? entries.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 7 days of usage',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppTheme.textSecondary.withValues(alpha: 0.65),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _colors[i % _colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entries[i].key,
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.95),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 45,
                          sections: List.generate(
                            entries.length,
                            (i) => PieChartSectionData(
                              value: entries[i].value,
                              color: _colors[i % _colors.length],
                              radius: 28,
                              showTitle: false,
                            ),
                          ),
                        ),
                      ),
                      if (top != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${top.value.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              top.key,
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${entries[i].value.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _colors[i % _colors.length],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
