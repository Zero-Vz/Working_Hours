import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/utils/calc.dart';
import 'package:working_hours/core/utils/time_utils.dart';
import 'package:working_hours/data/csv/record_csv_service.dart';
import 'package:working_hours/data/models/app_settings.dart';
import 'package:working_hours/data/models/overtime_record.dart';

void main() {
  group('时长计算', () {
    test('普通时段', () {
      expect(calcDurationMinutes('18:00', '21:00'), 180);
      expect(isOvernightRange('18:00', '21:00'), isFalse);
    });

    test('跨天自动加 24 小时', () {
      expect(calcDurationMinutes('22:00', '02:30'), 270);
      expect(isOvernightRange('22:00', '02:30'), isTrue);
    });

    test('刚好跨零点', () {
      expect(calcDurationMinutes('23:30', '00:10'), 40);
    });

    test('时间格式化', () {
      expect(formatDuration(180), '3小时');
      expect(formatDuration(125), '2小时05分');
      expect(minutesToTime(510), '08:30');
      expect(parseTimeToMinutes('08:30'), 510);
      expect(parseTimeToMinutes('24:00'), isNull);
    });
  });

  group('折算工时与金额', () {
    const settings = AppSettings(hourlyWage: 50);

    OvertimeRecord record({int minutes = 180, double rate = 1.5}) {
      final now = DateTime(2026, 10, 5, 9, 30);
      return OvertimeRecord(
        id: 1,
        date: DateTime(2026, 10, 5),
        startTime: '18:00',
        endTime: '21:00',
        durationMinutes: minutes,
        type: '工作日',
        rate: rate,
        amount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('折算工时 = 时长 × 倍率', () {
      expect(
        WorkCalc.convertedHours(
          durationMinutes: 180,
          rate: 1.5,
          deductBreak: false,
          breakMinutes: 30,
          roundToMinute: true,
        ),
        closeTo(4.5, 0.0001),
      );
      expect(WorkCalc.hoursOf(record(), settings), closeTo(4.5, 0.0001));
    });

    test('金额 = 折算工时 × 时薪，保留两位小数', () {
      expect(WorkCalc.amountOf(record(), settings), 225.00);
      expect(WorkCalc.money(4.5, 50), 225.00);
      expect(WorkCalc.money(1.239, 1), 1.24);
      expect(WorkCalc.money(0, 50), 0);
    });

    test('扣除休息时间', () {
      expect(
        WorkCalc.effectiveMinutes(180, deductBreak: true, breakMinutes: 30),
        150,
      );
      expect(
        WorkCalc.effectiveMinutes(20, deductBreak: true, breakMinutes: 30),
        0,
      );
    });

    test('四舍五入到分钟', () {
      // 61 分钟 × 1.5 = 91.5 分钟 → 开启取整为 92 分钟
      expect(
        WorkCalc.convertedHours(
          durationMinutes: 61,
          rate: 1.5,
          deductBreak: false,
          breakMinutes: 0,
          roundToMinute: true,
        ),
        closeTo(92 / 60, 0.0001),
      );
      expect(
        WorkCalc.convertedHours(
          durationMinutes: 61,
          rate: 1.5,
          deductBreak: false,
          breakMinutes: 0,
          roundToMinute: false,
        ),
        closeTo(91.5 / 60, 0.0001),
      );
    });
  });

  group('CSV 导出与解析', () {
    test('导出后重新解析结果一致', () {
      final now = DateTime(2026, 10, 5, 9, 30);
      final source = OvertimeRecord(
        id: 7,
        date: DateTime(2026, 10, 5),
        startTime: '18:00',
        endTime: '02:30',
        durationMinutes: calcDurationMinutes('18:00', '02:30'),
        type: '休息日',
        rate: 2,
        project: '机房割接,含"引号"',
        note: '跨天加班',
        isCompensatory: false,
        isSettled: true,
        amount: 566.67,
        createdAt: now,
        updatedAt: now,
      );

      final text = RecordCsvService.exportToString([source]);
      final parsed = RecordCsvService.parse(text);

      expect(parsed, hasLength(1));
      final item = parsed.single;
      expect(formatDateKey(item.date), '2026-10-05');
      expect(item.startTime, '18:00');
      expect(item.endTime, '02:30');
      expect(item.durationMinutes, 510);
      expect(item.type, '休息日');
      expect(item.rate, 2);
      expect(item.project, '机房割接,含"引号"');
      expect(item.note, '跨天加班');
      expect(item.isCompensatory, isFalse);
      expect(item.isSettled, isTrue);
      expect(item.amount, 566.67);
    });

    test('缺少表头时抛出异常', () {
      expect(
        () => RecordCsvService.parse('18:00,21:00'),
        throwsFormatException,
      );
    });
  });
}
