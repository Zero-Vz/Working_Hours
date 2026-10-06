import '../../core/utils/time_utils.dart';

/// 一段「生效起止日期」内的月薪
///
/// 录入方式：默认按起止日期记录调薪，比逐月填写更省事；
/// 结束日期为空表示一直生效到至今。
class SalaryRange {
  const SalaryRange({
    required this.start,
    required this.amount,
    this.end,
  });

  /// 生效起始日期（含当天）
  final DateTime start;

  /// 生效结束日期（含当天），null 表示至今
  final DateTime? end;

  /// 该期间的月薪（元 / 月）
  final double amount;

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// [date] 是否落在该区间内
  bool covers(DateTime date) {
    final day = _day(date);
    if (day.isBefore(_day(start))) return false;
    final stop = end;
    if (stop != null && day.isAfter(_day(stop))) return false;
    return true;
  }

  /// 是否与某月有交集（用于按月展示 / 月度取值）
  bool overlapsMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    if (_day(start).isAfter(last)) return false;
    final stop = end;
    if (stop != null && _day(stop).isBefore(first)) return false;
    return true;
  }

  /// 结束日期是否早于起始日期（非法区间）
  bool get invalid => end != null && _day(end!).isBefore(_day(start));

  String get startText => _format(start);

  String get endText => end == null ? '至今' : _format(end!);

  /// 展示文本：`2026-01-01 ~ 至今`
  String get label => '$startText ~ $endText';

  static String _format(DateTime value) =>
      '${value.year}-${pad2(value.month)}-${pad2(value.day)}';

  static DateTime? _parse(Object? raw) {
    if (raw is DateTime) return _day(raw);
    if (raw is! String) return null;
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'start': startText,
        'end': endText == '至今' ? '' : endText,
        'amount': amount,
      };

  /// 从备份 / Box 中解析，非法条目返回 null
  static SalaryRange? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final start = _parse(raw['start']);
    if (start == null) return null;
    final amount = (raw['amount'] as num?)?.toDouble();
    if (amount == null || amount < 0) return null;
    final end = _parse(raw['end']);
    final range = SalaryRange(start: start, end: end, amount: amount);
    return range.invalid ? null : range;
  }

  @override
  String toString() => 'SalaryRange($label, $amount)';
}
