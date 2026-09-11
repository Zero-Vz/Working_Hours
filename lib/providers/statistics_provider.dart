import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/overtime_record.dart';
import '../utils/calculations.dart';
import 'settings_provider.dart';

/// 月度统计数据
class MonthlyStats {
  final int totalMinutes;
  final double convertedHours;
  final double totalAmount;
  final Map<OvertimeType, int> typeMinutes;
  final Map<OvertimeType, double> typeAmounts;

  MonthlyStats({
    this.totalMinutes = 0,
    this.convertedHours = 0,
    this.totalAmount = 0,
    this.typeMinutes = const {},
    this.typeAmounts = const {},
  });
}

/// 年度月度统计数据
class MonthlySummary {
  final int month;
  final int totalMinutes;
  final double convertedHours;
  final double totalAmount;

  MonthlySummary({
    required this.month,
    required this.totalMinutes,
    required this.convertedHours,
    required this.totalAmount,
  });
}

/// 当前月统计
final monthlyStatsProvider = FutureProvider.family<MonthlyStats, DateTime>((ref, month) async {
  final db = DatabaseHelper.instance;
  final records = await db.getRecordsByMonth(month.year, month.month);
  final settings = ref.watch(settingsProvider);

  final hourlyWage = double.tryParse(settings['hourly_wage'] ?? '50.0') ?? 50.0;
  final deductBreak = settings['deduct_break'] == '1';
  final breakMins = int.tryParse(settings['break_minutes'] ?? '0') ?? 0;

  int totalMinutes = 0;
  double convertedHours = 0;
  double totalAmount = 0;
  final typeMinutes = <OvertimeType, int>{};
  final typeAmounts = <OvertimeType, double>{};

  for (final record in records) {
    int duration = record.durationMinutes;
    if (deductBreak && breakMins > 0) {
      duration = Calculations.deductBreakMinutes(duration, breakMins);
    }
    totalMinutes += duration;
    final hours = Calculations.calculateConvertedHours(duration, record.rate);
    convertedHours += hours;
    final amount = Calculations.calculateAmount(duration, record.rate, hourlyWage);
    totalAmount += amount;

    typeMinutes[record.type] = (typeMinutes[record.type] ?? 0) + duration;
    typeAmounts[record.type] = (typeAmounts[record.type] ?? 0) + amount;
  }

  return MonthlyStats(
    totalMinutes: totalMinutes,
    convertedHours: double.parse(convertedHours.toStringAsFixed(2)),
    totalAmount: double.parse(totalAmount.toStringAsFixed(2)),
    typeMinutes: typeMinutes,
    typeAmounts: typeAmounts,
  );
});

/// 年度月度汇总
final yearlyMonthlySummaryProvider = FutureProvider.family<List<MonthlySummary>, int>((ref, year) async {
  final db = DatabaseHelper.instance;
  final records = await db.getRecordsByYear(year);
  final settings = ref.watch(settingsProvider);

  final hourlyWage = double.tryParse(settings['hourly_wage'] ?? '50.0') ?? 50.0;
  final deductBreak = settings['deduct_break'] == '1';
  final breakMins = int.tryParse(settings['break_minutes'] ?? '0') ?? 0;

  final monthMap = <int, List<OvertimeRecord>>{};
  for (final record in records) {
    final m = record.date.month;
    monthMap.putIfAbsent(m, () => []).add(record);
  }

  final summaries = <MonthlySummary>[];
  for (int m = 1; m <= 12; m++) {
    final monthRecords = monthMap[m] ?? [];
    int totalMinutes = 0;
    double convertedHours = 0;
    double totalAmount = 0;

    for (final record in monthRecords) {
      int duration = record.durationMinutes;
      if (deductBreak && breakMins > 0) {
        duration = Calculations.deductBreakMinutes(duration, breakMins);
      }
      totalMinutes += duration;
      convertedHours += Calculations.calculateConvertedHours(duration, record.rate);
      totalAmount += Calculations.calculateAmount(duration, record.rate, hourlyWage);
    }

    summaries.add(MonthlySummary(
      month: m,
      totalMinutes: totalMinutes,
      convertedHours: double.parse(convertedHours.toStringAsFixed(2)),
      totalAmount: double.parse(totalAmount.toStringAsFixed(2)),
    ));
  }

  return summaries;
});