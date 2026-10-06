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

/// 节假日数据（三类日期集合，元素统一为 `yyyy-MM-dd`）
///
/// 内置数据见 [kStatutoryHolidays] / [kHolidayBreaks] / [kMakeupWorkdays]，
/// 也可通过「联网更新 / 导入文件」扩展后续年份。
class HolidayData {
  const HolidayData({
    this.statutory = const <String>{},
    this.makeup = const <String>{},
    this.breaks = const <String>{},
  });

  /// 法定节假日（3 倍薪资当天）
  final Set<String> statutory;

  /// 调休补班日（周末上班，按工作日）
  final Set<String> makeup;

  /// 放假连休的全部日期（含法定当天与调休休息日）
  final Set<String> breaks;

  /// 内置数据（随 APK 发布的 2025 / 2026 年安排）
  static HolidayData get builtin => HolidayData(
        statutory: kStatutoryHolidays,
        makeup: kMakeupWorkdays,
        breaks: kHolidayBreaks,
      );

  /// 数据覆盖的年份（升序）
  Set<int> get years {
    final result = <int>{};
    for (final key in <String>{...statutory, ...makeup, ...breaks}) {
      final year = _yearOf(key);
      if (year > 0) result.add(year);
    }
    return result;
  }

  /// 日期总条数
  int get length => statutory.length + makeup.length + breaks.length;

  bool get isEmpty => length == 0;

  /// 返回「本数据中出现过的年份被 incoming 覆盖」后的新数据，
  /// 未被覆盖的年份保持原样（导入 2027 年数据不会影响 2025 / 2026）。
  HolidayData withReplacedYears(HolidayData incoming) {
    if (incoming.isEmpty) return this;
    final incomingYears = incoming.years;
    Set<String> keep(Set<String> base) => <String>{
          for (final key in base)
            if (!incomingYears.contains(_yearOf(key))) key,
        };
    return HolidayData(
      statutory: <String>{...keep(statutory), ...incoming.statutory},
      makeup: <String>{...keep(makeup), ...incoming.makeup},
      breaks: <String>{...keep(breaks), ...incoming.breaks},
    );
  }

  /// 由键值表还原（供备份 / 缓存读取）
  factory HolidayData.fromMap(Map<dynamic, dynamic>? map) {
    Set<String> read(String key) => map?[key] is List
        ? (map![key] as List).whereType<String>().toSet()
        : <String>{};
    return HolidayData(
      statutory: read('statutory'),
      makeup: read('makeup'),
      breaks: read('breaks'),
    );
  }

  /// 序列化为键值表
  Map<String, dynamic> toMap() => <String, dynamic>{
        'statutory': statutory.toList()..sort(),
        'makeup': makeup.toList()..sort(),
        'breaks': breaks.toList()..sort(),
      };

  static int _yearOf(String key) {
    if (key.length < 4) return -1;
    return int.tryParse(key.substring(0, 4)) ?? -1;
  }
}

/// 日期写法规整：
///
/// - `2027-01-01` → 单日
/// - `2027-01-01..2027-01-03` → 展开为首尾齐全的区间
///
/// 格式非法时返回空集合（由调用方统计被忽略的数量）。
Set<String> expandDateSpec(String spec) {
  final raw = spec.trim();
  if (raw.isEmpty) return <String>{};
  if (!raw.contains('..')) return _isDateKey(raw) ? <String>{raw} : <String>{};

  final parts = raw.split('..');
  if (parts.length != 2) return <String>{};
  final start = _parseDateKey(parts[0].trim());
  final end = _parseDateKey(parts[1].trim());
  if (start == null || end == null || end.isBefore(start)) return <String>{};
  return _daysBetween(start, end);
}

bool _isDateKey(String value) => _parseDateKey(value) != null;

DateTime? _parseDateKey(String value) {
  if (value.length != 10) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// 按日历自动推断日期属性
class CalendarRules {
  const CalendarRules._();

  /// 当前生效的节假日数据：
  /// 默认为内置数据，联网更新 / 导入文件后由 [setActive] 切换。
  static HolidayData activeData = HolidayData.builtin;

  /// 切换生效的节假日数据（HolidayStore 写入后调用）
  static void setActive(HolidayData data) => activeData = data;

  /// 是否为周末（周六 / 周日）
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  /// 是否为调休补班日（周末但要上班）
  static bool isMakeupWorkday(DateTime date) =>
      activeData.makeup.contains(formatDateKey(date));

  /// 是否为法定节假日（3 倍）
  static bool isStatutoryHoliday(DateTime date) =>
      activeData.statutory.contains(formatDateKey(date));

  /// 是否在放假连休期间（含法定当天与调休休息日）
  static bool isHolidayBreak(DateTime date) =>
      activeData.breaks.contains(formatDateKey(date));

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
