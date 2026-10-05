/// 时间 / 日期格式化与计算工具（全部离线计算，不依赖网络）
library;

/// 补齐两位数
String pad2(int value) => value.toString().padLeft(2, '0');

/// 解析 "08:30" => 510（当天第 510 分钟），非法返回 null
int? parseTimeToMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/// 分钟数 => "HH:mm"
String minutesToTime(int minutes) {
  final normalized = ((minutes % 1440) + 1440) % 1440;
  return '${pad2(normalized ~/ 60)}:${pad2(normalized % 60)}';
}

/// 计算原始时长（分钟）。
/// 结束时间 <= 开始时间时按跨天处理（自动加 24 小时）。
/// 结束时间 == 开始时间属于非法输入，由保存前校验拦截，此处返回 1440。
int calcDurationMinutes(String startTime, String endTime) {
  final start = parseTimeToMinutes(startTime) ?? 0;
  final end = parseTimeToMinutes(endTime) ?? 0;
  final diff = end - start;
  return diff > 0 ? diff : diff + 1440;
}

/// 是否为跨天（结束时间不晚于开始时间）
bool isOvernightRange(String startTime, String endTime) {
  final start = parseTimeToMinutes(startTime);
  final end = parseTimeToMinutes(endTime);
  if (start == null || end == null) return false;
  return end <= start;
}

/// 时长格式化：2 小时 05 分
String formatDuration(int minutes) {
  if (minutes <= 0) return '0分钟';
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  if (hour == 0) return '$minute分钟';
  if (minute == 0) return '$hour小时';
  return '$hour小时${pad2(minute)}分';
}

/// 小时数格式化：保留两位小数
String formatHours(double hours) {
  final rounded = (hours * 100).roundToDouble() / 100;
  final text = rounded.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}

/// 金额格式化：保留两位小数；为 0 时直接显示 0
String formatMoney(double value) {
  if (value == 0) return '0';
  return value.toStringAsFixed(2);
}

/// 天数格式化：1 → 1，1.5 → 1.5（去掉多余的小数 0）
String formatDays(double days) {
  final rounded = (days * 100).roundToDouble() / 100;
  return rounded == rounded.truncateToDouble()
      ? '${rounded.toInt()}'
      : '$rounded';
}

/// 2026-10-05
String formatDateKey(DateTime date) =>
    '${date.year}-${pad2(date.month)}-${pad2(date.day)}';

/// 2026年10月5日
String formatDateCn(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日';

/// 10月05日
String formatDateShort(DateTime date) =>
    '${pad2(date.month)}月${pad2(date.day)}日';

/// 周日
String weekdayCn(DateTime date) => '周${'一二三四五六日'[date.weekday - 1]}';

/// 2026年10月
String formatMonthCn(DateTime month) => '${month.year}年${month.month}月';

/// 去掉时间部分
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 年月标识（用于 provider.family 的 key，保证相等性正确）
class YearMonth {
  const YearMonth(this.year, this.month);

  factory YearMonth.of(DateTime date) => YearMonth(date.year, date.month);

  final int year;
  final int month;

  DateTime get date => DateTime(year, month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-$month';
}
