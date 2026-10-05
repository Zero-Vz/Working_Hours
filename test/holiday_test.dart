import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/holidays.dart';

void main() {
  group('按日历自动推断加班类型', () {
    test('法定节假日按节假日（3 倍）', () {
      expect(CalendarRules.autoTypeFor(DateTime(2025, 1, 28)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 1, 29)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 10, 1)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 10, 6)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 1, 1)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 2, 17)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 4, 5)), '节假日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 10, 3)), '节假日');
      expect(CalendarRules.isStatutoryHoliday(DateTime(2026, 10, 3)), isTrue);
    });

    test('放假连休中非法定日按休息日（2 倍）', () {
      expect(CalendarRules.autoTypeFor(DateTime(2025, 2, 3)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 5, 5)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 10, 4)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 2, 20)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 4, 6)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 5, 4)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 10, 5)), '休息日');
    });

    test('调休补班的周末按工作日（1.5 倍）', () {
      expect(CalendarRules.autoTypeFor(DateTime(2025, 1, 26)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 2, 8)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 4, 27)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 9, 28)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 10, 11)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 1, 4)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 2, 14)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 5, 9)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 10, 10)), '工作日');
      expect(CalendarRules.isMakeupWorkday(DateTime(2026, 2, 28)), isTrue);
    });

    test('普通周末为休息日、工作日为工作日', () {
      // 2026-10-03 周六为国庆法定假日；2026-10-11 周日为普通周末
      expect(CalendarRules.autoTypeFor(DateTime(2026, 10, 11)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2026, 10, 12)), '工作日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 3, 15)), '休息日');
      expect(CalendarRules.autoTypeFor(DateTime(2025, 3, 17)), '工作日');
    });

    test('所有法定假日都落在放假区间内', () {
      for (final key in kStatutoryHolidays) {
        expect(
          kHolidayBreaks.contains(key),
          isTrue,
          reason: '$key 应在放假区间内',
        );
      }
      // 补班日不应落在放假区间内
      for (final key in kMakeupWorkdays) {
        expect(
          kHolidayBreaks.contains(key),
          isFalse,
          reason: '$key 为补班日，不应在放假区间内',
        );
      }
    });

    test('描述文案', () {
      expect(CalendarRules.describe(DateTime(2026, 10, 1)), '法定节假日，按节假日');
      expect(CalendarRules.describe(DateTime(2026, 2, 14)), '调休补班日，按工作日');
      expect(CalendarRules.describe(DateTime(2026, 10, 11)), '周末，按休息日');
      expect(CalendarRules.describe(DateTime(2026, 10, 12)), '工作日');
    });
  });
}
