import 'dart:math';

import '../../data/models/app_settings.dart';
import '../../data/models/overtime_record.dart';
import '../constants.dart';

/// 工时 / 金额计算规则
///
/// - 时长 = 结束时间 - 开始时间，跨天自动加 24 小时（见 time_utils）
/// - 扣除休息时间开启后，有效时长 = 时长 - 休息分钟数
/// - 按倍率：折算工时 = 有效时长 × 倍率，金额 = 折算工时 × 时薪
/// - 按固定时薪：折算工时 = 有效时长，金额 = 有效时长 × 固定加班时薪
class WorkCalc {
  const WorkCalc._();

  /// 月薪反推时薪：月薪 ÷ 21.75 ÷ 8
  static double hourlyFromMonthly(double monthly) =>
      monthly / kMonthlyPayDays / kDailyWorkHours;

  /// 扣除休息时间后的有效分钟数
  static int effectiveMinutes(
    int durationMinutes, {
    required bool deductBreak,
    required int breakMinutes,
  }) {
    if (!deductBreak || breakMinutes <= 0) return durationMinutes;
    return max(0, durationMinutes - breakMinutes);
  }

  /// 折算工时（小时）
  ///
  /// [roundToMinute] 为 true 时，折算结果先四舍五入到分钟再换算成小时。
  static double convertedHours({
    required int durationMinutes,
    required double rate,
    required bool deductBreak,
    required int breakMinutes,
    required bool roundToMinute,
  }) {
    final effective = effectiveMinutes(
      durationMinutes,
      deductBreak: deductBreak,
      breakMinutes: breakMinutes,
    );
    final double convertedMinutes =
        roundToMinute ? (effective * rate).roundToDouble() : effective * rate;
    return convertedMinutes / 60.0;
  }

  /// 有效时长（小时）：扣除休息后、不乘倍率
  static double actualHours({
    required int durationMinutes,
    required bool deductBreak,
    required int breakMinutes,
  }) {
    return effectiveMinutes(
      durationMinutes,
      deductBreak: deductBreak,
      breakMinutes: breakMinutes,
    ) /
        60.0;
  }

  /// 金额 = 折算工时 × 时薪，保留两位小数
  static double money(double hours, double hourlyWage) {
    final value = hours * hourlyWage;
    return double.parse(value.toStringAsFixed(2));
  }

  /// 记录使用的固定加班时薪（记录自带值优先，缺失时回退到设置默认值）
  static double fixedWageOf(OvertimeRecord record, AppSettings settings) {
    return record.fixedWage > 0 ? record.fixedWage : settings.fixedWage;
  }

  /// 按记录 + 当前设置计算折算工时
  static double hoursOf(OvertimeRecord record, AppSettings settings) {
    if (record.calcMode == CalcModes.fixed) {
      return actualHours(
        durationMinutes: record.durationMinutes,
        deductBreak: settings.deductBreak,
        breakMinutes: settings.breakMinutes,
      );
    }
    return convertedHours(
      durationMinutes: record.durationMinutes,
      rate: record.rate,
      deductBreak: settings.deductBreak,
      breakMinutes: settings.breakMinutes,
      roundToMinute: settings.roundToMinute,
    );
  }

  /// 按记录 + 当前设置计算金额
  static double amountOf(OvertimeRecord record, AppSettings settings) {
    if (record.calcMode == CalcModes.fixed) {
      return money(
        actualHours(
          durationMinutes: record.durationMinutes,
          deductBreak: settings.deductBreak,
          breakMinutes: settings.breakMinutes,
        ),
        fixedWageOf(record, settings),
      );
    }
    return money(hoursOf(record, settings), settings.effectiveHourlyWage);
  }
}
