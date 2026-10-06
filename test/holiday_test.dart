import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/holidays.dart';
import 'package:working_hours/data/holiday_file_service.dart';
import 'package:working_hours/data/update_check_service.dart';

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

  group('节假日数据按年份覆盖', () {
    test('内置数据覆盖 2025 / 2026 两个年份', () {
      final builtin = HolidayData.builtin;
      expect(builtin.years.toList()..sort(), <int>[2025, 2026]);
      expect(builtin.isEmpty, isFalse);
      expect(builtin.length, greaterThan(0));
    });

    test('导入新一年数据只覆盖该年，其他年份保留', () {
      final incoming = HolidayData(
        statutory: {'2027-01-01'},
        makeup: {'2027-01-24'},
        breaks: expandDateSpec('2027-01-01..2027-01-05'),
      );
      final merged = HolidayData.builtin.withReplacedYears(incoming);

      expect(merged.years.toList()..sort(), <int>[2025, 2026, 2027]);
      expect(merged.statutory.contains('2025-01-01'), isTrue);
      expect(merged.statutory.contains('2026-01-01'), isTrue);
      expect(CalendarRules.activeData.statutory.contains('2027-01-01'),
          isFalse,
          reason: '合并结果未生效前不应影响当前日历');
    });

    test('同一年份再次更新会整年替换旧值', () {
      final first = HolidayData.builtin;
      const second = HolidayData(
        statutory: {'2025-01-01'}, // 只保留元旦一个法定日
        makeup: <String>{},
        breaks: <String>{},
      );
      final merged = first.withReplacedYears(second);

      expect(merged.years.toList()..sort(), <int>[2025, 2026]);
      final legal2025 =
          merged.statutory.where((k) => k.startsWith('2025-')).toList();
      expect(legal2025, <String>['2025-01-01']);
      // 其他年份原样保留
      expect(merged.statutory.any((k) => k.startsWith('2026-')), isTrue);
    });

    test('序列化与还原保持一致', () {
      const data = HolidayData(
        statutory: {'2027-01-01', '2027-01-02'},
        makeup: {'2027-02-07'},
        breaks: {'2027-01-01', '2027-01-02'},
      );
      final restored = HolidayData.fromMap(data.toMap());
      expect(restored.statutory, unorderedEquals(data.statutory));
      expect(restored.makeup, unorderedEquals(data.makeup));
      expect(restored.breaks, unorderedEquals(data.breaks));
      expect(restored.length, data.length);
    });
  });

  group('日期写法规整', () {
    test('单日与区间展开', () {
      expect(expandDateSpec('2027-01-01'), <String>{'2027-01-01'});
      expect(
        expandDateSpec('2027-01-01..2027-01-03').toList()..sort(),
        <String>['2027-01-01', '2027-01-02', '2027-01-03'],
      );
      expect(expandDateSpec('  2027-01-01  '), <String>{'2027-01-01'});
    });

    test('非法写法返回空集合', () {
      expect(expandDateSpec(''), isEmpty);
      expect(expandDateSpec('2027-13-01'), isEmpty);
      expect(expandDateSpec('2027-01-01..2026-12-31'), isEmpty);
      expect(expandDateSpec('明天'), isEmpty);
    });
  });

  group('节假日文件解析（JSON / CSV）', () {
    test('JSON：字段、区间与名称', () {
      const text = '''
      {
        "name": "2027年放假安排",
        "statutory": ["2027-01-01"],
        "makeup": ["2027-02-07"],
        "breaks": ["2027-01-01..2027-01-03"]
      }''';
      final result = HolidayFileService.parse(text);
      expect(result.name, '2027年放假安排');
      expect(result.data.statutory, unorderedEquals(<String>['2027-01-01']));
      expect(result.data.makeup, unorderedEquals(<String>['2027-02-07']));
      expect(
        result.data.breaks,
        unorderedEquals(
          <String>['2027-01-01', '2027-01-02', '2027-01-03'],
        ),
      );
      expect(result.ignored, 0);
    });

    test('JSON：非法日期被忽略并计数', () {
      const text = '''
      {"statutory": ["2027-01-01", "2027-02-30", "元旦"]}''';
      final result = HolidayFileService.parse(text);
      expect(result.data.statutory, unorderedEquals(<String>['2027-01-01']));
      expect(result.ignored, 2);
    });

    test('JSON：结构无法识别时抛出异常', () {
      expect(() => HolidayFileService.parse('{"statutory": []}'),
          throwsFormatException);
      expect(() => HolidayFileService.parse('{"note": "hello"}'),
          throwsFormatException);
    });

    test('CSV：按表头解析三类日期', () {
      const text = 'kind,date,note\n'
          'statutory,2027-01-01,元旦\n'
          'makeup,2027-02-07,春节调休\n'
          'break,2027-01-01..2027-01-03,元旦连休\n';
      final result = HolidayFileService.parse(text, name: '2027.csv');
      expect(result.name, '2027.csv');
      expect(result.data.statutory, unorderedEquals(<String>['2027-01-01']));
      expect(result.data.makeup, unorderedEquals(<String>['2027-02-07']));
      expect(result.data.breaks.length, 3);
      expect(result.ignored, 0);
    });

    test('CSV：缺少表头抛出异常', () {
      expect(() => HolidayFileService.parse('2027-01-01,法定'),
          throwsFormatException);
    });
  });

  group('检查软件更新', () {
    test('版本比较：远端更高才算新版本', () {
      expect(UpdateCheckService.isNewer('v1.6.0', '1.5.0'), isTrue);
      expect(UpdateCheckService.isNewer('1.5.1', '1.5.0'), isTrue);
      expect(UpdateCheckService.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateCheckService.isNewer('1.5.0', '1.5.0'), isFalse);
      expect(UpdateCheckService.isNewer('1.4.9', '1.5.0'), isFalse);
      expect(UpdateCheckService.isNewer('v1.5.0+5', '1.5.0'), isFalse);
      expect(UpdateCheckService.isNewer('', '1.5.0'), isFalse);
    });

    test('解析 Releases 风格的返回内容', () {
      const text = '''
      {"tag_name": "v1.6.0", "html_url": "https://example.com/r/1",
       "body": "新增节假日联网更新"}''';
      final info = UpdateCheckService.parse(text);
      expect(info.version, '1.6.0');
      expect(info.url, 'https://example.com/r/1');
      expect(info.notes, '新增节假日联网更新');
      expect(UpdateCheckService.isNewer(info.version), isTrue);
    });

    test('缺少版本号时抛出异常', () {
      expect(() => UpdateCheckService.parse('{"html_url": "x"}'),
          throwsFormatException);
      expect(() => UpdateCheckService.parse('[]'), throwsFormatException);
    });
  });
}
