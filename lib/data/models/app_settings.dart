import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/constants.dart';

/// 应用设置（存放在 settings Box 中，全部为本地键值）
class AppSettings {
  const AppSettings({
    this.hourlyWage = 0.0,
    this.workdayRate = 1.5,
    this.restDayRate = 2.0,
    this.holidayRate = 3.0,
    this.customRate = 1.0,
    this.deductBreak = false,
    this.breakMinutes = 30,
    this.roundToMinute = true,
    this.themeMode = 'system',
    this.defaultProject = '',
  });

  /// 时薪（元 / 小时）
  final double hourlyWage;

  /// 各加班类型默认倍率
  final double workdayRate;
  final double restDayRate;
  final double holidayRate;
  final double customRate;

  /// 是否扣除休息时间
  final bool deductBreak;

  /// 每条记录扣除的休息分钟数
  final int breakMinutes;

  /// 折算工时是否四舍五入到分钟
  final bool roundToMinute;

  /// system / light / dark
  final String themeMode;

  /// 默认项目名
  final String defaultProject;

  ThemeMode get theme {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 某加班类型的默认倍率
  double defaultRateOf(String type) {
    switch (type) {
      case OvertimeTypes.weekday:
        return workdayRate;
      case OvertimeTypes.restDay:
        return restDayRate;
      case OvertimeTypes.holiday:
        return holidayRate;
      default:
        return customRate;
    }
  }

  AppSettings copyWith({
    double? hourlyWage,
    double? workdayRate,
    double? restDayRate,
    double? holidayRate,
    double? customRate,
    bool? deductBreak,
    int? breakMinutes,
    bool? roundToMinute,
    String? themeMode,
    String? defaultProject,
  }) {
    return AppSettings(
      hourlyWage: hourlyWage ?? this.hourlyWage,
      workdayRate: workdayRate ?? this.workdayRate,
      restDayRate: restDayRate ?? this.restDayRate,
      holidayRate: holidayRate ?? this.holidayRate,
      customRate: customRate ?? this.customRate,
      deductBreak: deductBreak ?? this.deductBreak,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      roundToMinute: roundToMinute ?? this.roundToMinute,
      themeMode: themeMode ?? this.themeMode,
      defaultProject: defaultProject ?? this.defaultProject,
    );
  }

  /// 从本地 Box 读取（缺失键使用默认值）
  factory AppSettings.read(Box box) {
    double number(String key, double fallback) =>
        (box.get(key, defaultValue: fallback) as num?)?.toDouble() ?? fallback;
    int integer(String key, int fallback) =>
        (box.get(key, defaultValue: fallback) as num?)?.toInt() ?? fallback;

    return AppSettings(
      hourlyWage: number('hourlyWage', 0),
      workdayRate: number('workdayRate', 1.5),
      restDayRate: number('restDayRate', 2),
      holidayRate: number('holidayRate', 3),
      customRate: number('customRate', 1),
      deductBreak: box.get('deductBreak', defaultValue: false) as bool? ?? false,
      breakMinutes: integer('breakMinutes', 30),
      roundToMinute: box.get('roundToMinute', defaultValue: true) as bool? ?? true,
      themeMode:
          box.get('themeMode', defaultValue: 'system') as String? ?? 'system',
      defaultProject: box.get('defaultProject', defaultValue: '') as String? ?? '',
    );
  }

  /// 写入本地 Box
  Future<void> write(Box box) => box.putAll(<String, dynamic>{
        'hourlyWage': hourlyWage,
        'workdayRate': workdayRate,
        'restDayRate': restDayRate,
        'holidayRate': holidayRate,
        'customRate': customRate,
        'deductBreak': deductBreak,
        'breakMinutes': breakMinutes,
        'roundToMinute': roundToMinute,
        'themeMode': themeMode,
        'defaultProject': defaultProject,
      });
}
