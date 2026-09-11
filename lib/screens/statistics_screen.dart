import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/overtime_record.dart';
import '../providers/records_provider.dart';
import '../providers/statistics_provider.dart';
import '../utils/calculations.dart';
import '../widgets/charts/yearly_trend_chart.dart';
import '../widgets/charts/monthly_bar_chart.dart';

/// 统计页
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(selectedMonth));
    final yearlySummaryAsync = ref.watch(yearlyMonthlySummaryProvider(selectedMonth.year));

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 月份切换
          _buildMonthNavigation(context, ref, selectedMonth),
          const SizedBox(height: 16),

          // 月度统计卡片
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (stats) => _buildMonthlyStatsCards(context, stats),
          ),
          const SizedBox(height: 24),

          // 按类型汇总
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _buildTypeSummary(context, stats),
          ),
          const SizedBox(height: 24),

          // 年度趋势图
          Text(
            '年度趋势（${selectedMonth.year}）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          yearlySummaryAsync.when(
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (summaries) => YearlyTrendChart(summaries: summaries),
          ),
          const SizedBox(height: 24),

          // 月度加班费柱状图
          Text(
            '月度加班费（${selectedMonth.year}）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          yearlySummaryAsync.when(
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (summaries) => MonthlyBarChart(summaries: summaries),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation(BuildContext context, WidgetRef ref, DateTime selectedMonth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(selectedMonth.year, selectedMonth.month - 1);
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          ),
          child: Text(
            '${selectedMonth.year}年${selectedMonth.month}月',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(selectedMonth.year, selectedMonth.month + 1);
          },
        ),
      ],
    );
  }

  Widget _buildMonthlyStatsCards(BuildContext context, MonthlyStats stats) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.schedule,
            title: '总加班时长',
            value: Calculations.formatDuration(stats.totalMinutes),
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.hourglass_top,
            title: '折算工时',
            value: Calculations.formatHours(stats.convertedHours),
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.payments,
            title: '预计加班费',
            value: Calculations.formatAmount(stats.totalAmount),
            color: colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSummary(BuildContext context, MonthlyStats stats) {
    if (stats.typeMinutes.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '按类型汇总',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...OvertimeType.values.map((type) {
          final minutes = stats.typeMinutes[type] ?? 0;
          final amount = stats.typeAmounts[type] ?? 0.0;
          if (minutes == 0) return const SizedBox.shrink();

          Color typeColor;
          switch (type) {
            case OvertimeType.workday:
              typeColor = colorScheme.primary;
              break;
            case OvertimeType.restday:
              typeColor = colorScheme.secondary;
              break;
            case OvertimeType.holiday:
              typeColor = colorScheme.error;
              break;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(type.label),
              subtitle: Text('${Calculations.formatDuration(minutes)} | 折算 ${Calculations.formatHours(Calculations.calculateConvertedHours(minutes, type.defaultRate))}'),
              trailing: Text(
                Calculations.formatAmount(amount),
                style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}