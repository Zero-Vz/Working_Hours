import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../providers/statistics_provider.dart';

/// 月度加班费柱状图
class MonthlyBarChart extends StatelessWidget {
  final List<MonthlySummary> summaries;

  const MonthlyBarChart({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (summaries.isEmpty || summaries.every((s) => s.totalAmount == 0)) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final maxAmount = summaries
        .map((s) => s.totalAmount)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, left: 6, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
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
                        meta: meta,
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
                    return Text('¥${value.toInt()}', style: const TextStyle(fontSize: 10));
                  },
                  reservedSize: 50,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: summaries.map((s) {
              return BarChartGroupData(
                x: s.month,
                barRods: [
                  BarChartRodData(
                    toY: s.totalAmount,
                    color: colorScheme.primary,
                    width: 16,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxAmount > 0 ? maxAmount * 1.2 : 100,
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                  ),
                ],
              );
            }).toList(),
            maxY: maxAmount > 0 ? maxAmount * 1.2 : 100,
          ),
        ),
      ),
    );
  }
}