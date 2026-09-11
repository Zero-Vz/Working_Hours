/// 应用常量
class AppConstants {
  static const String appName = '加班记';
  static const String dbName = 'jiabanji.db';

  // 默认倍率
  static const double defaultWorkdayRate = 1.5;
  static const double defaultRestdayRate = 2.0;
  static const double defaultHolidayRate = 3.0;

  // 默认时薪
  static const double defaultHourlyWage = 50.0;

  // 设置键名
  static const String keyHourlyWage = 'hourly_wage';
  static const String keyWorkdayRate = 'workday_rate';
  static const String keyRestdayRate = 'restday_rate';
  static const String keyHolidayRate = 'holiday_rate';
  static const String keyDeductBreak = 'deduct_break';
  static const String keyRoundToMinute = 'round_to_minute';
  static const String keyBreakMinutes = 'break_minutes';
}