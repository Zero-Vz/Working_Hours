import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/utils/calc.dart';
import '../core/utils/time_utils.dart';
import 'records_provider.dart';
import 'settings_provider.dart';

/// 单个加班类型的汇总
class TypeSummary {
  const TypeSummary({
    required this.type,
    required this.count,
    required this.hours,
    required this.amount,
  });

  final String type;
  final int count;
  final double hours;
  final double amount;
}

/// 单月统计
class MonthlyStats {
  const MonthlyStats({
    required this.key,
    required this.count,
    required this.rawMinutes,
    required this.hours,
    required this.amount,
    required this.byType,
  });

  final YearMonth key;

  /// 记录条数
  final int count;

  /// 原始加班总时长（分钟）
  final int rawMinutes;

  /// 折算工时（小时）
  final double hours;

  /// 预计金额
  final double amount;

  /// 按加班类型汇总
  final List<TypeSummary> byType;
}

/// 统计页当前查看的年份
final statsYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// 单月统计
final monthlyStatsProvider = Provider.family<MonthlyStats, YearMonth>(
  (ref, key) {
    final records = ref.watch(recordsProvider);
    final settings = ref.watch(settingsProvider);

    final matched = records
        .where((record) =>
            record.date.year == key.year && record.date.month == key.month)
        .toList();

    var rawMinutes = 0;
    var hours = 0.0;
    var amount = 0.0;
    final buckets = <String, List<double>>{};
    for (final record in matched) {
      final recordHours = WorkCalc.hoursOf(record, settings);
      final recordAmount = WorkCalc.amountOf(record, settings);
      rawMinutes += record.durationMinutes;
      hours += recordHours;
      amount += recordAmount;

      final bucket =
          buckets.putIfAbsent(record.type, () => <double>[0, 0, 0]);
      bucket[0] += 1;
      bucket[1] += recordHours;
      bucket[2] += recordAmount;
    }

    final byType = <TypeSummary>[];
    for (final type in OvertimeTypes.all) {
      final bucket = buckets[type];
      if (bucket == null) continue;
      byType.add(
        TypeSummary(
          type: type,
          count: bucket[0].round(),
          hours: bucket[1],
          amount: bucket[2],
        ),
      );
    }

    return MonthlyStats(
      key: key,
      count: matched.length,
      rawMinutes: rawMinutes,
      hours: hours,
      amount: amount,
      byType: byType,
    );
  },
);

/// 年度趋势：12 个月的折算工时（小时）
final yearTrendProvider = Provider.family<List<double>, int>((ref, year) {
  final stats = ref.watch(_yearStatsProvider(year));
  return stats.map((month) => month.hours).toList();
});

/// 年度金额：12 个月的预计金额
final yearAmountProvider = Provider.family<List<double>, int>((ref, year) {
  final stats = ref.watch(_yearStatsProvider(year));
  return stats.map((month) => month.amount).toList();
});

final _yearStatsProvider =
    Provider.family<List<MonthlyStats>, int>((ref, year) {
  return [
    for (var month = 1; month <= 12; month++)
      ref.watch(monthlyStatsProvider(YearMonth(year, month))),
  ];
});

/// 月度柱状图：当月每天的折算工时（小时），长度 = 当月天数
final monthDailyHoursProvider =
    Provider.family<List<double>, YearMonth>((ref, key) {
  final records = ref.watch(recordsProvider);
  final settings = ref.watch(settingsProvider);
  final days = DateTime(key.year, key.month + 1, 0).day;
  final result = List<double>.filled(days, 0);

  for (final record in records) {
    if (record.date.year != key.year || record.date.month != key.month) continue;
    result[record.date.day - 1] += WorkCalc.hoursOf(record, settings);
  }
  return result;
});
