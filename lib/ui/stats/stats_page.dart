import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/stats_provider.dart';

/// 统计页：本月汇总、类型汇总、年度趋势、月度柱状图
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final year = ref.watch(statsYearProvider);
    final monthKey = YearMonth.of(now);
    final stats = ref.watch(monthlyStatsProvider(monthKey));
    final trend = ref.watch(yearTrendProvider(year));
    final daily = ref.watch(monthDailyHoursProvider(monthKey));
    final hasYearData = trend.any((value) => value > 0);
    final hasMonthData = daily.any((value) => value > 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            tooltip: '上一年',
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(statsYearProvider.notifier).state = year - 1,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref.read(statsYearProvider.notifier).state = now.year,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                '$year 年',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一年',
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                ref.read(statsYearProvider.notifier).state = year + 1,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月概览（${formatMonthCn(now)}）',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: '本月加班时长',
                    value: formatDuration(stats.rawMinutes),
                    icon: Icons.timelapse_outlined,
                    color: scheme.primary,
                    total: stats.count,
                    unitSuffix: ' 条记录',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: '本月折算工时',
                    value: formatHours(stats.hours),
                    unit: '小时',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF00897B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: '本月加班费',
                    value: formatMoney(stats.amount),
                    unit: '元',
                    prefix: '¥',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFB26A00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme,
              title: '按加班类型汇总',
              child: stats.byType.isEmpty
                  ? Text('本月暂无记录', style: theme.textTheme.bodySmall)
                  : _buildTypeSummary(theme, stats),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme,
              title: '$year 年度趋势（折算工时 / 小时）',
              trailing: Text(
                '全年 ${formatHours(trend.fold(0.0, (a, b) => a + b))} 小时',
                style: theme.textTheme.bodySmall,
              ),
              child: SizedBox(
                height: 240,
                child: hasYearData
                    ? _YearTrendChart(
                        trend: trend,
                        color: scheme.primary,
                        scheme: scheme,
                      )
                    : _EmptyChart(theme: theme, text: '该年度暂无数据'),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme,
              title: '${formatMonthCn(now)} 每日加班（折算工时 / 小时）',
              trailing: Text(
                '共 ${stats.count} 条',
                style: theme.textTheme.bodySmall,
              ),
              child: SizedBox(
                height: 240,
                child: hasMonthData
                    ? _MonthDailyChart(daily: daily, color: scheme.primary)
                    : _EmptyChart(theme: theme, text: '本月暂无数据'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSummary(ThemeData theme, MonthlyStats stats) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final item in stats.byType)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  OvertimeTypes.iconOf(item.type),
                  size: 18,
                  color: OvertimeTypes.colorOf(item.type),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(item.type, style: theme.textTheme.bodyMedium),
                ),
                Text('${item.count} 条', style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(
                  '${formatHours(item.hours)} 小时',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    '¥${formatMoney(item.amount)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                '合计',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${formatHours(stats.hours)} 小时',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  '¥${formatMoney(stats.amount)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.unit = '',
    this.prefix = '',
    this.total = 0,
    this.unitSuffix = '',
  });

  final String title;
  final String value;
  final String unit;
  final String prefix;
  final IconData icon;
  final Color color;
  final int total;
  final String unitSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: prefix),
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (unitSuffix.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$total$unitSuffix',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// 年度趋势折线图（横轴 1-12 月）
class _YearTrendChart extends StatelessWidget {
  const _YearTrendChart({
    required this.trend,
    required this.color,
    required this.scheme,
  });

  final List<double> trend;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final maxValue = trend.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.3;
    final interval = maxY / 4;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value >= 10 ? value.toStringAsFixed(0) : formatHours(value),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final month = value.toInt();
                if (month < 1 || month > 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$month月',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < trend.length; i++) FlSpot(i + 1, trend[i]),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

/// 月度每日柱状图（横轴 1-N 日）
class _MonthDailyChart extends StatelessWidget {
  const _MonthDailyChart({required this.daily, required this.color});

  final List<double> daily;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = daily.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.3;
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: interval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value >= 10 ? value.toStringAsFixed(0) : formatHours(value),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day < 1 || day > daily.length) {
                  return const SizedBox.shrink();
                }
                final show = day == 1 || day % 5 == 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    show ? '$day' : '',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < daily.length; i++)
            BarChartGroupData(
              x: i + 1,
              barRods: [
                BarChartRodData(
                  toY: daily[i],
                  width: daily.length > 28 ? 6 : 12,
                  color: daily[i] > 0 ? color : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
      swapAnimationDuration: const Duration(milliseconds: 350),
    );
  }
}
