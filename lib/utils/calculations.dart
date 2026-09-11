import 'package:flutter/material.dart';

/// 计算工具类
class Calculations {
  /// 计算加班时长（分钟），支持跨天
  static int calculateDurationMinutes(TimeOfDay start, TimeOfDay end) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;
    int diff = endMinutes - startMinutes;
    // 如果结束时间小于开始时间，说明跨天了
    if (diff <= 0) {
      diff += 24 * 60;
    }
    return diff;
  }

  /// 扣除休息时间后的时长
  static int deductBreakMinutes(int durationMinutes, int breakMinutes) {
    if (breakMinutes <= 0) return durationMinutes;
    final result = durationMinutes - breakMinutes;
    return result < 0 ? 0 : result;
  }

  /// 四舍五入到分钟（已经是分钟精度，此方法保留用于未来扩展）
  static int roundToMinute(int minutes) {
    return minutes;
  }

  /// 计算折算工时（小时）
  static double calculateConvertedHours(int durationMinutes, double rate) {
    final hours = durationMinutes / 60.0;
    return hours * rate;
  }

  /// 计算预计加班费
  static double calculateAmount(int durationMinutes, double rate, double hourlyWage) {
    final convertedHours = calculateConvertedHours(durationMinutes, rate);
    return double.parse((convertedHours * hourlyWage).toStringAsFixed(2));
  }

  /// 格式化时长为 "X小时Y分钟"
  static String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins分钟';
    if (mins == 0) return '$hours小时';
    return '$hours小时$mins分钟';
  }

  /// 格式化时间为 "HH:mm"
  static String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化金额
  static String formatAmount(double amount) {
    return '¥${amount.toStringAsFixed(2)}';
  }

  /// 格式化折算工时
  static String formatHours(double hours) {
    return '${hours.toStringAsFixed(2)}小时';
  }
}