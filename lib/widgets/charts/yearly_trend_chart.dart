import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../providers/statistics_provider.dart';

/// 年度趋势折线图
class YearlyTrendChart extends StatelessWidget {
  final List<MonthlySummary> summaries;

  const YearlyTrendChart({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (summaries.isEmpty || summaries.every((s) => s.totalMinutes == 0)) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final maxHours = summaries
        .map((s) => s.convertedHours)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, left: 6, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxHours > 0 ? (maxHours / 4).ceilToDouble() : 10,
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
                    final idx = value.toInt() - 1;
                    if (idx >= 0 && idx < months.length) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(months[idx], style: const TextStyle(fontSize: 10)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
                  },
                  reservedSize: 40,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: summaries
                    .map((s) => FlSpot(s.month.toDouble(), s.convertedHours))
                    .toList(),
                isCurved: true,
                color: colorScheme.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: colorScheme.primary,
                      strokeWidth: 2,
                      strokeColor: colorScheme.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ],
            minY: 0,
            maxY: maxHours > 0 ? (maxHours * 1.2) : 10,
          ),
        ),
      ),
    );
  }
}