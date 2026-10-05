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

/// 应用版本号（关于页展示）
const String kAppVersion = '1.0.0';
