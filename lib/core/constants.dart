import 'package:flutter/material.dart';

/// 本地数据库 Box 名称
class BoxNames {
  static const String records = 'records';
  static const String settings = 'settings';
}

/// 加班类型及其内置默认倍率
class OvertimeTypes {
  static const String weekday = '工作日';
  static const String restDay = '休息日';
  static const String holiday = '节假日';
  static const String custom = '自定义';

  /// 全部加班类型（顺序即展示顺序）
  static const List<String> all = [weekday, restDay, holiday, custom];

  /// 内置默认倍率（可在设置页修改）
  static const Map<String, double> builtinRates = <String, double>{
    weekday: 1.5,
    restDay: 2.0,
    holiday: 3.0,
    custom: 1.0,
  };

  static double builtinRateOf(String type) => builtinRates[type] ?? 1.0;

  static IconData iconOf(String type) {
    switch (type) {
      case weekday:
        return Icons.work_outline;
      case restDay:
        return Icons.weekend_outlined;
      case holiday:
        return Icons.celebration_outlined;
      default:
        return Icons.tune_outlined;
    }
  }

  static Color colorOf(String type) {
    switch (type) {
      case weekday:
        return const Color(0xFF3F51B5);
      case restDay:
        return const Color(0xFF00897B);
      case holiday:
        return const Color(0xFFD84315);
      default:
        return const Color(0xFF6D4C41);
    }
  }
}

/// 单条记录的计算方式
///
/// - [rate]：按倍率，金额 = 有效时长 × 倍率 × 时薪
/// - [fixed]：按固定加班时薪，金额 = 有效时长 × 固定加班时薪
class CalcModes {
  static const String rate = 'rate';
  static const String fixed = 'fixed';

  static const List<String> all = [rate, fixed];

  static String labelOf(String mode) => mode == fixed ? '固定时薪' : '按倍率';

  static String normalize(String? value) =>
      value == fixed ? fixed : rate;
}

/// 薪资录入方式（用于反推时薪）
class SalaryModes {
  /// 直接填写时薪
  static const String hourly = 'hourly';

  /// 填写月薪，时薪 = 月薪 ÷ 21.75 ÷ 8
  static const String monthly = 'monthly';

  static const List<String> all = [hourly, monthly];

  static String normalize(String? value) => value == monthly ? monthly : hourly;
}

/// 月计薪天数（人社部规定的月平均工作日）
const double kMonthlyPayDays = 21.75;

/// 每日标准工作小时数
const double kDailyWorkHours = 8.0;

/// 应用版本号（关于页展示）
const String kAppVersion = '1.2.0';
