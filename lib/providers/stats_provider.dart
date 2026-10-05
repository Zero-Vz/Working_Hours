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
    required this.deductedMinutes,
    required this.hours,
    required this.amount,
    required this.byType,
  });

  final YearMonth key;

  /// 记录条数
  final int count;

  /// 原始加班总时长（分钟，未扣休息）
  final int rawMinutes;

  /// 按设置实际扣除的休息分钟数
  final int deductedMinutes;

  /// 扣除休息后的有效时长（分钟）
  int get effectiveMinutes => rawMinutes - deductedMinutes;

  /// 折算工时（小时）
  final double hours;

  /// 预计金额
  final double amount;

  /// 按加班类型汇总
  final List<TypeSummary> byType;
}

/// 年度统计（12 个月汇总）
class YearStats {
  const YearStats({
    required this.year,
    required this.count,
    required this.rawMinutes,
    required this.deductedMinutes,
    required this.hours,
    required this.amount,
    required this.byType,
  });

  final int year;
  final int count;
  final int rawMinutes;
  final int deductedMinutes;
  final double hours;
  final double amount;
  final List<TypeSummary> byType;

  int get effectiveMinutes => rawMinutes - deductedMinutes;
}

/// 统计页：是否按年度查看（false = 月度，true = 年度）
final statsByYearProvider = StateProvider<bool>((ref) => false);

/// 统计页当前查看的年份
final statsYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// 统计页当前查看的月份（月度模式）
final statsMonthProvider =
    StateProvider<YearMonth>((ref) => YearMonth.of(DateTime.now()));

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
    var deductedMinutes = 0;
    var hours = 0.0;
    var amount = 0.0;
    final buckets = <String, List<double>>{};
    for (final record in matched) {
      final recordHours = WorkCalc.hoursOf(record, settings);
      final recordAmount = WorkCalc.amountOf(record, settings);
      final effective = WorkCalc.effectiveMinutes(
        record.durationMinutes,
        deductBreak: settings.deductBreak,
        breakMinutes: settings.breakMinutes,
      );
      rawMinutes += record.durationMinutes;
      deductedMinutes += record.durationMinutes - effective;
      hours += recordHours;
      amount += recordAmount;

      final bucket =
          buckets.putIfAbsent(record.type, () => <double>[0, 0, 0]);
      bucket[0] += 1;
      bucket[1] += recordHours;
      bucket[2] += recordAmount;
    }

    return MonthlyStats(
      key: key,
      count: matched.length,
      rawMinutes: rawMinutes,
      deductedMinutes: deductedMinutes,
      hours: hours,
      amount: amount,
      byType: _mergeTypeOrder(buckets),
    );
  },
);

/// 年度统计
final yearStatsProvider = Provider.family<YearStats, int>((ref, year) {
  final months = [
    for (var month = 1; month <= 12; month++)
      ref.watch(monthlyStatsProvider(YearMonth(year, month))),
  ];

  var count = 0;
  var rawMinutes = 0;
  var deductedMinutes = 0;
  var hours = 0.0;
  var amount = 0.0;
  final buckets = <String, List<double>>{};
  for (final month in months) {
    count += month.count;
    rawMinutes += month.rawMinutes;
    deductedMinutes += month.deductedMinutes;
    hours += month.hours;
    amount += month.amount;
    for (final item in month.byType) {
      final bucket = buckets.putIfAbsent(
        item.type,
        () => <double>[0, 0, 0],
      );
      bucket[0] += item.count;
      bucket[1] += item.hours;
      bucket[2] += item.amount;
    }
  }

  return YearStats(
    year: year,
    count: count,
    rawMinutes: rawMinutes,
    deductedMinutes: deductedMinutes,
    hours: hours,
    amount: amount,
    byType: _mergeTypeOrder(buckets),
  );
});

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

/// 按固定顺序输出类型汇总
List<TypeSummary> _mergeTypeOrder(Map<String, List<double>> buckets) {
  final result = <TypeSummary>[];
  for (final type in OvertimeTypes.all) {
    final bucket = buckets[type];
    if (bucket == null) continue;
    result.add(
      TypeSummary(
        type: type,
        count: bucket[0].round(),
        hours: bucket[1],
        amount: bucket[2],
      ),
    );
  }
  return result;
}
