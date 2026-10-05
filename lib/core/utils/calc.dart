import 'dart:math';

import '../../data/models/app_settings.dart';
import '../../data/models/overtime_record.dart';

/// 工时 / 金额计算规则
///
/// - 时长 = 结束时间 - 开始时间，跨天自动加 24 小时（见 time_utils）
/// - 折算工时 = 实际时长（可扣除休息）× 倍率
/// - 预计加班费 = 折算工时 × 时薪，保留两位小数
class WorkCalc {
  const WorkCalc._();

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

  /// 金额 = 折算工时 × 时薪，保留两位小数
  static double money(double hours, double hourlyWage) {
    final value = hours * hourlyWage;
    return double.parse(value.toStringAsFixed(2));
  }

  /// 按记录 + 当前设置计算折算工时
  static double hoursOf(OvertimeRecord record, AppSettings settings) {
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
    return money(hoursOf(record, settings), settings.hourlyWage);
  }
}
