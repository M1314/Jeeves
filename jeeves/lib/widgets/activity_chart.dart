/// Bar chart widget for monthly activity data (posts or comments).
///
/// [ActivityChart] wraps the `fl_chart` [BarChart] to display time-series
/// data returned by [DatabaseHelper.getPostActivityByMonth] or
/// [DatabaseHelper.getCommentActivityByMonth].
///
/// At most 24 months are shown at once to keep the chart readable on narrow
/// screens; if more data is available the oldest months are truncated.
///
/// X-axis labels show the two-digit month number (e.g. `"03"` for March).
/// Y-axis labels show raw item counts.  A 15% headroom is added above the
/// highest bar so the tallest bar never clips against the top edge.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

/// A fixed-height bar chart that displays [ActivityPoint] data per month.
///
/// Pass a distinct [barColor] to differentiate posts (indigo) from comments
/// (teal) in the Analytics dashboard.
class ActivityChart extends StatelessWidget {
  /// The data points to render; each [ActivityPoint.label] is a `"YYYY-MM"`
  /// string and [ActivityPoint.count] is the number of items for that month.
  final List<ActivityPoint> data;

  /// Fill colour for all bars in the chart.
  final Color barColor;

  /// Human-readable heading displayed above the chart, e.g.
  /// `"Posts per month"`.
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

    // Show a placeholder when no data has been synced yet.
    if (data.isEmpty) {
      return Center(
        child: Text('No data yet.', style: theme.textTheme.bodyMedium),
      );
    }

    // Limit to the most recent 24 months so the bars are not too narrow.
    final visible = data.length > 24 ? data.sublist(data.length - 24) : data;
    // The maximum count drives the Y-axis ceiling.
    final maxY = visible.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart title
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
                // Add 15 % headroom above the tallest bar to prevent clipping.
                maxY: (maxY * 1.15).ceilToDouble(),
                gridData: const FlGridData(
                  // Suppress vertical grid lines; horizontal lines are enough
                  // context for reading bar heights.
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  // Y-axis (left): show integer count labels.
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
                  // X-axis (bottom): show one label per ~6 bars so labels
                  // don't overlap on narrow screens.
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      // Show approximately 6 evenly-spaced labels.
                      interval: (visible.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= visible.length) {
                          return const SizedBox.shrink();
                        }
                        // Label format is "YYYY-MM"; show just the two-digit
                        // month for brevity.
                        final label = visible[idx].label;
                        final parts = label.split('-');
                        return Text(
                          parts.length == 2 ? parts[1] : label,
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                  // Suppress right and top axes — they add visual noise without
                  // providing additional information.
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                // Remove the chart border for a cleaner look.
                borderData: FlBorderData(show: false),
                // Map each ActivityPoint to a BarChartGroupData.
                barGroups: visible.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.count.toDouble(),
                        color: barColor,
                        width: 10,
                        // Slightly rounded top corners to match Material 3 style.
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
