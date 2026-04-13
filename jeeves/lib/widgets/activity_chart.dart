import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

/// Bar chart showing post or comment counts per month.
class ActivityChart extends StatelessWidget {
  final List<ActivityPoint> data;
  final Color barColor;
  final String title;

  const ActivityChart({
    super.key,
    required this.data,
    required this.title,
    this.barColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return Center(
        child: Text('No data yet.', style: theme.textTheme.bodyMedium),
      );
    }

    // Show at most the last 24 months to keep the chart readable
    final visible = data.length > 24 ? data.sublist(data.length - 24) : data;
    final maxY = visible.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        SizedBox(
          height: 160,
          child: Padding(
            padding:
                const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
            child: BarChart(
              BarChartData(
                maxY: (maxY * 1.15).ceilToDouble(),
                gridData: const FlGridData(
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (visible.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= visible.length) {
                          return const SizedBox.shrink();
                        }
                        // label is "YYYY-MM"; show just MM
                        final label = visible[idx].label;
                        final parts = label.split('-');
                        return Text(
                          parts.length == 2 ? parts[1] : label,
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: visible.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.count.toDouble(),
                        color: barColor,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
