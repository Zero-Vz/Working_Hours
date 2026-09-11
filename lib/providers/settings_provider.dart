import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

/// 时薪
final hourlyWageProvider = FutureProvider<double>((ref) async {
  final db = DatabaseHelper.instance;
  return db.getHourlyWage();
});

/// 工作日倍率
final workdayRateProvider = FutureProvider<double>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyWorkdayRate, defaultValue: '1.5');
  return double.tryParse(val) ?? AppConstants.defaultWorkdayRate;
});

/// 休息日倍率
final restdayRateProvider = FutureProvider<double>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyRestdayRate, defaultValue: '2.0');
  return double.tryParse(val) ?? AppConstants.defaultRestdayRate;
});

/// 节假日倍率
final holidayRateProvider = FutureProvider<double>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyHolidayRate, defaultValue: '3.0');
  return double.tryParse(val) ?? AppConstants.defaultHolidayRate;
});

/// 是否扣除休息时间
final deductBreakProvider = FutureProvider<bool>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyDeductBreak, defaultValue: '0');
  return val == '1';
});

/// 是否四舍五入到分钟
final roundToMinuteProvider = FutureProvider<bool>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyRoundToMinute, defaultValue: '1');
  return val == '1';
});

/// 休息时间（分钟）
final breakMinutesProvider = FutureProvider<int>((ref) async {
  final db = DatabaseHelper.instance;
  final val = await db.getSetting(AppConstants.keyBreakMinutes, defaultValue: '0');
  return int.tryParse(val) ?? 0;
});

/// 设置操作Notifier
class SettingsNotifier extends StateNotifier<Map<String, String>> {
  SettingsNotifier() : super({});

  Future<void> loadSettings() async {
    final db = DatabaseHelper.instance;
    final wage = await db.getSetting(AppConstants.keyHourlyWage, defaultValue: '50.0');
    final workdayRate = await db.getSetting(AppConstants.keyWorkdayRate, defaultValue: '1.5');
    final restdayRate = await db.getSetting(AppConstants.keyRestdayRate, defaultValue: '2.0');
    final holidayRate = await db.getSetting(AppConstants.keyHolidayRate, defaultValue: '3.0');
    final deductBreak = await db.getSetting(AppConstants.keyDeductBreak, defaultValue: '0');
    final roundToMinute = await db.getSetting(AppConstants.keyRoundToMinute, defaultValue: '1');
    final breakMinutes = await db.getSetting(AppConstants.keyBreakMinutes, defaultValue: '0');

    state = {
      AppConstants.keyHourlyWage: wage,
      AppConstants.keyWorkdayRate: workdayRate,
      AppConstants.keyRestdayRate: restdayRate,
      AppConstants.keyHolidayRate: holidayRate,
      AppConstants.keyDeductBreak: deductBreak,
      AppConstants.keyRoundToMinute: roundToMinute,
      AppConstants.keyBreakMinutes: breakMinutes,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = DatabaseHelper.instance;
    await db.setSetting(key, value);
    state = {...state, key: value};
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Map<String, String>>((ref) {
  return SettingsNotifier()..loadSettings();
});