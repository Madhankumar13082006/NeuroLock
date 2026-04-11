import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AppUsageChart extends StatelessWidget {
  final Map<String, double> usageData;
  final Color appColor;

  const AppUsageChart({
    super.key,
    required this.usageData,
    required this.appColor,
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
    final entries = usageData.entries.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 Days of Usage',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Legend
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(entries[i].key,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ]),
                    );
                  }),
                ),
              ),
              // Donut chart
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
                      // Center label for largest segment
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entries.first.value.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            entries.first.key,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Percentages on right
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
