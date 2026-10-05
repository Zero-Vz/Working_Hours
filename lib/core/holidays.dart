/// 中国法定节假日日历（完全离线的内置数据表）
///
/// 数据来源：《国务院办公厅关于 2025 / 2026 年部分节假日安排的通知》
/// （国办发明电〔2024〕12 号、〔2025〕7 号）。
///
/// 三类日期：
/// - [kStatutoryHolidays]：法定节假日当天，加班按 3 倍（节假日）
/// - [kHolidayBreaks]：放假连休的全部日期（含法定当天与调休休息日），
///   非法定的连休日按休息日 2 倍处理
/// - [kMakeupWorkdays]：调休补班日（周末上班），按工作日 1.5 倍处理
///
/// 未收录的年份（例如 2027 年之后，国务院尚未发布安排）会自动退化为
/// “周六周日 = 休息日、工作日 = 工作日”的基础规则。
library;

import 'utils/time_utils.dart';

/// 某日期区间内的全部日期（含首尾）
Set<String> _daysBetween(DateTime start, DateTime end) {
  final result = <String>{};
  var current = dateOnly(start);
  final last = dateOnly(end);
  while (!current.isAfter(last)) {
    result.add(formatDateKey(current));
    current = DateTime(current.year, current.month, current.day + 1);
  }
  return result;
}

/// 法定节假日（3 倍薪资当天）
const Set<String> kStatutoryHolidays = <String>{
  // ---- 2025 年（13 天）----
  '2025-01-01', // 元旦
  '2025-01-28', // 春节·除夕
  '2025-01-29', // 春节·正月初一
  '2025-01-30', // 春节·正月初二
  '2025-01-31', // 春节·正月初三
  '2025-04-04', // 清明节
  '2025-05-01', // 劳动节
  '2025-05-02', // 劳动节
  '2025-05-31', // 端午节
  '2025-10-01', // 国庆节
  '2025-10-02', // 国庆节
  '2025-10-03', // 国庆节
  '2025-10-06', // 中秋节

  // ---- 2026 年（13 天）----
  '2026-01-01', // 元旦
  '2026-02-16', // 春节·除夕
  '2026-02-17', // 春节·正月初一
  '2026-02-18', // 春节·正月初二
  '2026-02-19', // 春节·正月初三
  '2026-04-05', // 清明节
  '2026-05-01', // 劳动节
  '2026-05-02', // 劳动节
  '2026-06-19', // 端午节
  '2026-09-25', // 中秋节
  '2026-10-01', // 国庆节
  '2026-10-02', // 国庆节
  '2026-10-03', // 国庆节
};

/// 调休补班日（周末上班，按工作日处理）
const Set<String> kMakeupWorkdays = <String>{
  // 2025 年
  '2025-01-26', // 周日，春节调休
  '2025-02-08', // 周六，春节调休
  '2025-04-27', // 周日，劳动节调休
  '2025-09-28', // 周日，国庆调休
  '2025-10-11', // 周六，国庆调休

  // 2026 年
  '2026-01-04', // 周日，元旦调休
  '2026-02-14', // 周六，春节调休
  '2026-02-28', // 周六，春节调休
  '2026-05-09', // 周六，劳动节调休
  '2026-09-20', // 周日，国庆调休
  '2026-10-10', // 周六，国庆调休
};

/// 放假连休的全部日期（含法定当天、调休休息日与普通周末）
final Set<String> kHolidayBreaks = <String>{
  // ---- 2025 年 ----
  ..._daysBetween(DateTime(2025, 1, 1), DateTime(2025, 1, 1)), // 元旦
  ..._daysBetween(DateTime(2025, 1, 28), DateTime(2025, 2, 4)), // 春节 8 天
  ..._daysBetween(DateTime(2025, 4, 4), DateTime(2025, 4, 6)), // 清明
  ..._daysBetween(DateTime(2025, 5, 1), DateTime(2025, 5, 5)), // 劳动节
  ..._daysBetween(DateTime(2025, 5, 31), DateTime(2025, 6, 2)), // 端午
  ..._daysBetween(DateTime(2025, 10, 1), DateTime(2025, 10, 8)), // 国庆中秋

  // ---- 2026 年 ----
  ..._daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 3)), // 元旦
  ..._daysBetween(DateTime(2026, 2, 15), DateTime(2026, 2, 23)), // 春节 9 天
  ..._daysBetween(DateTime(2026, 4, 4), DateTime(2026, 4, 6)), // 清明
  ..._daysBetween(DateTime(2026, 5, 1), DateTime(2026, 5, 5)), // 劳动节
  ..._daysBetween(DateTime(2026, 6, 19), DateTime(2026, 6, 21)), // 端午
  ..._daysBetween(DateTime(2026, 9, 25), DateTime(2026, 9, 27)), // 中秋
  ..._daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 7)), // 国庆
};

/// 按日历自动推断日期属性
class CalendarRules {
  const CalendarRules._();

  /// 是否为周末（周六 / 周日）
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  /// 是否为调休补班日（周末但要上班）
  static bool isMakeupWorkday(DateTime date) =>
      kMakeupWorkdays.contains(formatDateKey(date));

  /// 是否为法定节假日（3 倍）
  static bool isStatutoryHoliday(DateTime date) =>
      kStatutoryHolidays.contains(formatDateKey(date));

  /// 是否在放假连休期间（含法定当天与调休休息日）
  static bool isHolidayBreak(DateTime date) =>
      kHolidayBreaks.contains(formatDateKey(date));

  /// 根据日历自动推断加班类型：
  ///
  /// 调休补班日 → 工作日；法定节假日 → 节假日；
  /// 周末 / 放假连休 → 休息日；其余 → 工作日。
  static String autoTypeFor(DateTime date) {
    if (isMakeupWorkday(date)) return '工作日';
    if (isStatutoryHoliday(date)) return '节假日';
    if (isHolidayBreak(date) || isWeekend(date)) return '休息日';
    return '工作日';
  }

  /// 推断结果的中文说明（用于新增记录页提示）
  static String describe(DateTime date) {
    if (isMakeupWorkday(date)) return '调休补班日，按工作日';
    if (isStatutoryHoliday(date)) return '法定节假日，按节假日';
    if (isHolidayBreak(date)) return '放假连休，按休息日';
    if (isWeekend(date)) return '周末，按休息日';
    return '工作日';
  }
}
