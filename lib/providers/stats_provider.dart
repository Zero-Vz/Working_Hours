import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/holidays.dart';
import '../core/utils/calc.dart';
import '../core/utils/time_utils.dart';
import '../data/models/leave_record.dart';
import 'income_items_provider.dart';
import 'leaves_provider.dart';
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

/// 请假汇总
class LeaveSummary {
  const LeaveSummary({
    required this.count,
    required this.days,
    required this.paidDays,
    required this.unpaidDays,
    required this.deduct,
  });

  /// 请假条数
  final int count;

  /// 请假总天数
  final double days;

  /// 带薪天数
  final double paidDays;

  /// 无薪天数
  final double unpaidDays;

  /// 扣工资合计（带薪默认为 0，也可填写部分扣款）
  final double deduct;

  bool get isEmpty => count == 0;
}

/// 整月 / 全年工资构成
class SalaryBreakdown {
  const SalaryBreakdown({
    required this.months,
    required this.salary,
    required this.overtime,
    required this.incomeExtra,
    required this.incomeDeduct,
    required this.leaveDeduct,
    required this.total,
  });

  /// 参与计算的月数（单月 = 1，全年 = 12）
  final int months;

  /// 计入的月薪合计
  final double salary;

  /// 加班费
  final double overtime;

  /// 工资增项合计
  final double incomeExtra;

  /// 工资扣项合计
  final double incomeDeduct;

  /// 请假扣款
  final double leaveDeduct;

  /// 总工资 = 月薪 + 加班费 + 增项 - 扣项 - 请假扣款
  final double total;
}

/// 统计页：是否按年度查看（false = 月度，true = 年度）
final statsByYearProvider = StateProvider<bool>((ref) => false);

/// 统计页当前查看的年份
final statsYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// 统计页当前查看的月份（月度模式）
final statsMonthProvider =
    StateProvider<YearMonth>((ref) => YearMonth.of(DateTime.now()));

/// 单月加班统计
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
      final effective = WorkCalc.effectiveMinutesOf(record, settings);
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

/// 年度加班统计
final yearStatsProvider = Provider.family<YearStats, int>((ref, year) {
  final months = ref.watch(_yearStatsProvider(year));

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

/// 单月请假汇总
final monthLeaveSummaryProvider =
    Provider.family<LeaveSummary, YearMonth>((ref, key) {
  final leaves = ref.watch(leavesProvider);
  return _sumLeaves(
    leaves.where((item) =>
        item.date.year == key.year && item.date.month == key.month),
  );
});

/// 全年请假汇总
final yearLeaveSummaryProvider =
    Provider.family<LeaveSummary, int>((ref, year) {
  final leaves = ref.watch(leavesProvider);
  return _sumLeaves(leaves.where((item) => item.date.year == year));
});

/// 单月工资构成（整月总工资卡）
final monthBreakdownProvider =
    Provider.family<SalaryBreakdown, YearMonth>((ref, key) {
  final settings = ref.watch(settingsProvider);
  final overtime = ref.watch(monthlyStatsProvider(key)).amount;
  final leave = ref.watch(monthLeaveSummaryProvider(key));
  final totals = ref.watch(monthIncomeTotalsProvider(key));
  return _breakdown(
    months: 1,
    salaryTotal: settings.includeSalaryInTotal
        ? settings.salaryForYearMonth(key.year, key.month)
        : 0,
    overtime: overtime,
    leaveDeduct: leave.deduct,
    extra: totals.extra,
    deduct: totals.deduct,
  );
});

/// 全年工资构成（逐月累加，支持按月调薪与按月工资项金额）
final yearBreakdownProvider =
    Provider.family<SalaryBreakdown, int>((ref, year) {
  final settings = ref.watch(settingsProvider);
  final overtime = ref.watch(yearStatsProvider(year)).amount;
  final leave = ref.watch(yearLeaveSummaryProvider(year));

  var salary = 0.0;
  var extra = 0.0;
  var deduct = 0.0;
  for (var month = 1; month <= 12; month++) {
    if (settings.includeSalaryInTotal) {
      salary += settings.salaryForYearMonth(year, month);
    }
    final totals = ref.watch(monthIncomeTotalsProvider(YearMonth(year, month)));
    extra += totals.extra;
    deduct += totals.deduct;
  }
  return _breakdown(
    months: 12,
    salaryTotal: salary,
    overtime: overtime,
    leaveDeduct: leave.deduct,
    extra: extra,
    deduct: deduct,
  );
});

/// 月度金额趋势：当月每天的金额（元），长度 = 当月天数
///
/// 展示总工资模式下，开启「月薪计入总工资」或均摊开关时，
/// 会把月薪与固定工资项平摊到每个工作日（每个工作日 = 一天 8 小时的工资）。
final monthDailyAmountProvider =
    Provider.family<List<double>, YearMonth>((ref, key) {
  final records = ref.watch(recordsProvider);
  final settings = ref.watch(settingsProvider);
  final fixed = ref.watch(_fixedMonthlyForProvider(key));
  final days = DateTime(key.year, key.month + 1, 0).day;
  final result = List<double>.filled(days, 0);

  for (final record in records) {
    if (record.date.year != key.year || record.date.month != key.month) continue;
    result[record.date.day - 1] += WorkCalc.amountOf(record, settings);
  }

  if (fixed != 0 && settings.spreadDailyAmount) {
    final workdays = _workdaysInMonth(key);
    if (workdays > 0) {
      final perDay = fixed / workdays;
      for (var day = 1; day <= days; day++) {
        if (_isWorkday(DateTime(key.year, key.month, day))) {
          result[day - 1] += perDay;
        }
      }
    }
  }
  return result;
});

/// 年度金额趋势：12 个月的金额（元）
final yearAmountSeriesProvider =
    Provider.family<List<double>, int>((ref, year) {
  final settings = ref.watch(settingsProvider);
  final monthly = ref.watch(_yearStatsProvider(year));
  return [
    for (var i = 0; i < monthly.length; i++)
      monthly[i].amount +
          (settings.showTotalSalary
              ? ref.watch(_fixedMonthlyForProvider(YearMonth(year, i + 1)))
              : 0),
  ];
});

/// 月度时长趋势：每天的有效加班时长（小时）
final monthDailyHoursProvider =
    Provider.family<List<double>, YearMonth>((ref, key) {
  final records = ref.watch(recordsProvider);
  final settings = ref.watch(settingsProvider);
  final days = DateTime(key.year, key.month + 1, 0).day;
  final result = List<double>.filled(days, 0);
  for (final record in records) {
    if (record.date.year != key.year || record.date.month != key.month) continue;
    result[record.date.day - 1] +=
        WorkCalc.effectiveMinutesOf(record, settings) / 60.0;
  }
  return result;
});

/// 年度时长趋势：12 个月的有效加班时长（小时）
final yearMonthlyHoursProvider =
    Provider.family<List<double>, int>((ref, year) {
  final monthly = ref.watch(_yearStatsProvider(year));
  return [
    for (final month in monthly) month.effectiveMinutes / 60.0,
  ];
});

/// 月度请假扣款趋势：每天的请假扣款（元）
final monthLeaveDeductSeriesProvider =
    Provider.family<List<double>, YearMonth>((ref, key) {
  final leaves = ref.watch(leavesProvider);
  final days = DateTime(key.year, key.month + 1, 0).day;
  final result = List<double>.filled(days, 0);
  for (final item in leaves) {
    if (item.date.year != key.year || item.date.month != key.month) continue;
    result[item.date.day - 1] += item.actualDeduct;
  }
  return result;
});

/// 年度请假扣款趋势：12 个月的请假扣款（元）
final yearLeaveDeductSeriesProvider =
    Provider.family<List<double>, int>((ref, year) {
  final leaves = ref.watch(leavesProvider);
  final result = List<double>.filled(12, 0);
  for (final item in leaves) {
    if (item.date.year != year) continue;
    result[item.date.month - 1] += item.actualDeduct;
  }
  return result;
});

/// 月度增扣项趋势：当月增扣净额按工作日平摊（元 / 日）
final monthIncomeNetSeriesProvider =
    Provider.family<List<double>, YearMonth>((ref, key) {
  final net = ref.watch(monthIncomeTotalsProvider(key)).net;
  final days = DateTime(key.year, key.month + 1, 0).day;
  final result = List<double>.filled(days, 0);
  if (net == 0) return result;
  final workdays = _workdaysInMonth(key);
  if (workdays <= 0) return result;
  final perDay = net / workdays;
  for (var day = 1; day <= days; day++) {
    if (_isWorkday(DateTime(key.year, key.month, day))) {
      result[day - 1] = perDay;
    }
  }
  return result;
});

/// 年度增扣项趋势：12 个月的增扣净额（元）
final yearIncomeNetSeriesProvider =
    Provider.family<List<double>, int>((ref, year) {
  return [
    for (var month = 1; month <= 12; month++)
      ref.watch(monthIncomeTotalsProvider(YearMonth(year, month))).net,
  ];
});

/// 单月固定金额（月薪 + 增项 - 扣项），仅在展示总工资时计入
final _fixedMonthlyForProvider =
    Provider.family<double, YearMonth>((ref, key) {
  final settings = ref.watch(settingsProvider);
  if (!settings.showTotalSalary) return 0;
  final salary = settings.includeSalaryInTotal
      ? settings.salaryForYearMonth(key.year, key.month)
      : 0;
  final totals = ref.watch(monthIncomeTotalsProvider(key));
  return salary + totals.net;
});

final _yearStatsProvider =
    Provider.family<List<MonthlyStats>, int>((ref, year) {
  return [
    for (var month = 1; month <= 12; month++)
      ref.watch(monthlyStatsProvider(YearMonth(year, month))),
  ];
});

SalaryBreakdown _breakdown({
  required int months,
  required double salaryTotal,
  required double overtime,
  required double leaveDeduct,
  required double extra,
  required double deduct,
}) {
  return SalaryBreakdown(
    months: months,
    salary: salaryTotal,
    overtime: overtime,
    incomeExtra: extra,
    incomeDeduct: deduct,
    leaveDeduct: leaveDeduct,
    total: WorkCalc.totalSalary(
      includeSalary: false,
      monthlySalary: 0,
      overtimeAmount: overtime,
      incomeExtra: 0,
      incomeDeduct: 0,
      leaveDeduct: leaveDeduct,
      salaryTotal: salaryTotal,
      incomeExtraTotal: extra,
      incomeDeductTotal: deduct,
    ),
  );
}

LeaveSummary _sumLeaves(Iterable<LeaveRecord> matched) {
  var count = 0;
  var days = 0.0;
  var paidDays = 0.0;
  var unpaidDays = 0.0;
  var deduct = 0.0;
  for (final item in matched) {
    count++;
    days += item.days;
    if (item.isPaid) {
      paidDays += item.days;
    } else {
      unpaidDays += item.days;
    }
    deduct += item.actualDeduct;
  }
  return LeaveSummary(
    count: count,
    days: days,
    paidDays: paidDays,
    unpaidDays: unpaidDays,
    deduct: double.parse(deduct.toStringAsFixed(2)),
  );
}

/// 是否为工作日（工作日 / 调休补班日）
bool _isWorkday(DateTime date) =>
    CalendarRules.autoTypeFor(date) == OvertimeTypes.weekday;

/// 当月工作日天数
int _workdaysInMonth(YearMonth key) {
  final days = DateTime(key.year, key.month + 1, 0).day;
  var count = 0;
  for (var day = 1; day <= days; day++) {
    if (_isWorkday(DateTime(key.year, key.month, day))) count++;
  }
  return count;
}

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
