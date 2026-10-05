import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';

/// 统计页：月度 / 年度切换查看
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final byYear = ref.watch(statsByYearProvider);
    final year = ref.watch(statsYearProvider);
    final monthKey = ref.watch(statsMonthProvider);
    final settings = ref.watch(settingsProvider);

    final monthly = ref.watch(monthlyStatsProvider(monthKey));
    final yearly = ref.watch(yearStatsProvider(year));
    final breakdown = ref.watch(
      byYear
          ? yearBreakdownProvider(year)
          : monthBreakdownProvider(monthKey),
    );
    final leave = ref.watch(
      byYear
          ? yearLeaveSummaryProvider(year)
          : monthLeaveSummaryProvider(monthKey),
    );
    final series = ref.watch(
      byYear
          ? yearAmountSeriesProvider(year)
          : monthDailyAmountProvider(monthKey),
    );

    final labels = byYear
        ? <String>[for (var m = 1; m <= 12; m++) '$m月']
        : <String>[for (var d = 1; d <= series.length; d++) '$d'];
    final labelEvery = byYear ? 1 : 5;
    final hasData = series.any((value) => value != 0);
    final emptyText = byYear ? '该年度暂无数据' : '该月暂无数据';
    final chartTitle = byYear
        ? '$year 年每月金额趋势'
        : '${monthKey.month} 月每日金额趋势';

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------- 视图切换与周期选择
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('月度')),
                  ButtonSegment(value: true, label: Text('年度')),
                ],
                selected: {byYear},
                onSelectionChanged: (values) =>
                    ref.read(statsByYearProvider.notifier).state = values.first,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  tooltip: byYear ? '上一年' : '上一月',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    if (byYear) {
                      ref.read(statsYearProvider.notifier).state = year - 1;
                    } else {
                      final next =
                          DateTime(monthKey.year, monthKey.month - 1);
                      ref.read(statsMonthProvider.notifier).state =
                          YearMonth.of(next);
                    }
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      byYear
                          ? '$year 年'
                          : '${monthKey.year}年${monthKey.month}月',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: byYear ? '下一年' : '下一月',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    if (byYear) {
                      ref.read(statsYearProvider.notifier).state = year + 1;
                    } else {
                      final next =
                          DateTime(monthKey.year, monthKey.month + 1);
                      ref.read(statsMonthProvider.notifier).state =
                          YearMonth.of(next);
                    }
                  },
                ),
                IconButton(
                  tooltip: byYear ? '回到今年' : '回到本月',
                  icon: const Icon(Icons.today_outlined, size: 20),
                  onPressed: () {
                    if (byYear) {
                      ref.read(statsYearProvider.notifier).state = now.year;
                    } else {
                      ref.read(statsMonthProvider.notifier).state =
                          YearMonth.of(now);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ---------------------------- 指标卡（三张等高）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricCard(
                    title: byYear ? '全年加班时长' : '月度加班时长',
                    value: formatDuration(
                      byYear
                          ? yearly.effectiveMinutes
                          : monthly.effectiveMinutes,
                    ),
                    icon: Icons.timelapse_outlined,
                    color: scheme.primary,
                    hint: byYear
                        ? '${yearly.count} 条记录'
                        : '${monthly.count} 条记录',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: byYear ? '全年折算工时' : '月度折算工时',
                    value: formatHours(
                      byYear ? yearly.hours : monthly.hours,
                    ),
                    unit: '小时',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF00897B),
                    hint: byYear
                        ? '原始 ${formatDuration(yearly.rawMinutes)}'
                        : '原始 ${formatDuration(monthly.rawMinutes)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: byYear ? '全年加班费' : '月度加班费',
                    value: formatMoney(
                      byYear ? yearly.amount : monthly.amount,
                    ),
                    unit: '元',
                    prefix: '¥',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFFB26A00),
                    hint: byYear ? '$year 年累计' : '${monthKey.month} 月累计',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---------------------------- 整月总工资（含扣增）
            if (settings.showTotalSalary) ...[
              _sectionCard(
                theme,
                title: byYear ? '全年总工资（含扣增）' : '整月总工资（含扣增）',
                trailing: Text(
                  byYear ? '$year 年累计' : '${monthKey.month} 月应发',
                  style: theme.textTheme.bodySmall,
                ),
                child: _buildBreakdown(theme, breakdown, settings),
              ),
              const SizedBox(height: 16),
            ],

            // ---------------------------- 类型汇总
            _sectionCard(
              theme,
              title: byYear ? '按加班类型汇总（全年）' : '按加班类型汇总',
              child: (byYear ? yearly.byType : monthly.byType).isEmpty
                  ? Text(
                      byYear ? '该年度暂无记录' : '该月暂无记录',
                      style: theme.textTheme.bodySmall,
                    )
                  : _buildTypeSummary(
                      theme,
                      byYear ? yearly.byType : monthly.byType,
                      hours: byYear ? yearly.hours : monthly.hours,
                      amount: byYear ? yearly.amount : monthly.amount,
                    ),
            ),
            const SizedBox(height: 16),

            // ---------------------------- 请假汇总
            if (!leave.isEmpty) ...[
              _sectionCard(
                theme,
                title: byYear ? '全年请假汇总' : '当月请假汇总',
                trailing: Text(
                  '${leave.count} 次',
                  style: theme.textTheme.bodySmall,
                ),
                child: _buildLeaveSummary(theme, leave),
              ),
              const SizedBox(height: 16),
            ],

            // ---------------------------- 金额趋势（折线 + 条形，同一份数据）
            _sectionCard(
              theme,
              title: '$chartTitle · 折线',
              trailing: Text(
                '合计 ¥${formatMoney(series.fold<double>(0, (a, b) => a + b))}',
                style: theme.textTheme.bodySmall,
              ),
              child: SizedBox(
                height: 240,
                child: hasData
                    ? _LineChart(
                        values: series,
                        labels: labels,
                        labelEvery: labelEvery,
                        color: scheme.primary,
                        scheme: scheme,
                      )
                    : _EmptyChart(theme: theme, text: emptyText),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme,
              title: '$chartTitle · 条形',
              trailing: Text(
                '共 ${byYear ? yearly.count : monthly.count} 条',
                style: theme.textTheme.bodySmall,
              ),
              child: SizedBox(
                height: 240,
                child: hasData
                    ? _BarChart(
                        values: series,
                        labels: labels,
                        color: scheme.primary,
                        labelEvery: labelEvery,
                        scheme: scheme,
                      )
                    : _EmptyChart(theme: theme, text: emptyText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 工资构成明细
  Widget _buildBreakdown(
    ThemeData theme,
    SalaryBreakdown data,
    AppSettings settings,
  ) {
    final scheme = theme.colorScheme;
    Widget row(String label, String value, {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color ?? scheme.onSurface,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.salary > 0)
          row(
            '月薪${data.months > 1 ? ' ×${data.months}' : ''}',
            '¥${formatMoney(data.salary)}',
          ),
        row('加班费', '¥${formatMoney(data.overtime)}'),
        row('增项（补贴 / 绩效…）', '+ ¥${formatMoney(data.incomeExtra)}',
            color: const Color(0xFF2E7D32)),
        row('扣项（税费 / 保险…）', '- ¥${formatMoney(data.incomeDeduct)}',
            color: const Color(0xFFC62828)),
        row('请假扣款', '- ¥${formatMoney(data.leaveDeduct)}',
            color: data.leaveDeduct > 0 ? const Color(0xFFC62828) : null),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                '应发合计',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '¥${formatMoney(data.total)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '月薪${data.salary > 0 ? '已' : '未'}计入 · '
          '均摊${settings.spreadToWorkdays ? '已' : '未'}开启',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.outline,
          ),
        ),
      ],
    );
  }

  /// 请假汇总
  Widget _buildLeaveSummary(ThemeData theme, LeaveSummary data) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.beach_access_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '共 ${data.count} 次 · ${formatDays(data.days)} 天',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              data.paidDays > 0 ? '带薪 ${formatDays(data.paidDays)} 天' : '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.remove_circle_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.unpaidDays > 0
                    ? '无薪 ${formatDays(data.unpaidDays)} 天'
                    : '全部带薪',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              data.deduct > 0 ? '- ¥${formatMoney(data.deduct)}' : '不扣工资',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: data.deduct > 0 ? scheme.error : scheme.outline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSummary(
    ThemeData theme,
    List<TypeSummary> items, {
    required double hours,
    required double amount,
  }) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final item in items)
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
                '${formatHours(hours)} 小时',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  '¥${formatMoney(amount)}',
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

/// 图表提示文案：0 直接显示 0，其余保留两位小数
String _tooltipText(List<String> labels, int index, double value) {
  final label = (index >= 0 && index < labels.length) ? labels[index] : '';
  final text = '¥${formatMoney(value)}';
  return label.isEmpty ? text : '$label\n$text';
}

/// 指标卡：标题 / 数值 / 说明三段式，三张卡片高度保持一致
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.hint,
    this.unit = '',
    this.prefix = '',
  });

  final String title;
  final String value;
  final String unit;
  final String prefix;
  final String hint;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
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

/// 左轴刻度：金额，0 显示为 0
String _axisText(double value) =>
    value.abs() >= 10 ? value.toStringAsFixed(0) : formatMoney(value);

/// 金额趋势折线图
class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.values,
    required this.labels,
    required this.labelEvery,
    required this.color,
    required this.scheme,
  });

  final List<double> values;
  final List<String> labels;
  final int labelEvery;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final minValue = values.fold<double>(0, (a, b) => a < b ? a : b);
    final maxY = maxValue > 0 ? maxValue * 1.3 : 1.0;
    final minY = minValue < 0 ? minValue * 1.3 : 0.0;
    final interval = (maxY - minY) / 4;
    final dense = values.length > 12;

    return LineChart(
      LineChartData(
        minY: minY,
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
              reservedSize: 46,
              interval: interval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _axisText(value),
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
                final index = value.toInt();
                if (index < 1 || index > values.length) {
                  return const SizedBox.shrink();
                }
                final show = labelEvery <= 1 ||
                    index == 1 ||
                    index % labelEvery == 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    show ? labels[index - 1] : '',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            tooltipBorder: BorderSide(color: scheme.outlineVariant),
            getTooltipColor: (_) => scheme.surface,
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                _tooltipText(labels, spot.x.toInt() - 1, spot.y),
                TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i + 1, values[i]),
            ],
            isCurved: !dense,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: color,
            dotData: FlDotData(show: !dense),
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

/// 金额趋势条形图（与折线图同一份数据）
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.color,
    required this.labelEvery,
    required this.scheme,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  /// 标签显示间隔（1 = 全部显示）
  final int labelEvery;

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final minValue = values.fold<double>(0, (a, b) => a < b ? a : b);
    final maxY = maxValue > 0 ? maxValue * 1.3 : 1.0;
    final minY = minValue < 0 ? minValue * 1.3 : 0.0;
    final interval = (maxY - minY) / 4;
    final dense = values.length > 28;

    return BarChart(
      BarChartData(
        minY: minY,
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
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            tooltipBorder: BorderSide(color: scheme.outlineVariant),
            getTooltipColor: (_) => scheme.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                _tooltipText(labels, groupIndex, rod.toY),
                TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              );
            },
          ),
        ),
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
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _axisText(value),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: dense ? 24 : 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 1 || index > values.length) {
                  return const SizedBox.shrink();
                }
                final show = labelEvery <= 1 ||
                    index == 1 ||
                    index % labelEvery == 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    show ? labels[index - 1] : '',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i + 1,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: dense ? 6 : 12,
                  color: values[i] != 0 ? color : scheme.outlineVariant,
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
