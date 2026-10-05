import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/constants.dart';
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

  group('月薪反推时薪', () {
    test('时薪 = 月薪 ÷ 21.75 ÷ 8', () {
      expect(WorkCalc.hourlyFromMonthly(21750), closeTo(125, 0.0001));
      expect(WorkCalc.hourlyFromMonthly(8700), closeTo(50, 0.0001));
      expect(
        const AppSettings(salaryMode: 'monthly', monthlySalary: 21750)
            .effectiveHourlyWage,
        closeTo(125, 0.0001),
      );
      // 月薪未填写时时薪回退为 0
      expect(
        const AppSettings(salaryMode: 'monthly', monthlySalary: 0)
            .effectiveHourlyWage,
        0,
      );
      expect(
        const AppSettings(salaryMode: 'hourly', hourlyWage: 66)
            .effectiveHourlyWage,
        66,
      );
    });

    test('月薪模式下按反推时薪计算金额', () {
      const settings = AppSettings(
        salaryMode: 'monthly',
        monthlySalary: 21750, // 时薪 125
      );
      final now = DateTime(2026, 10, 5, 9, 30);
      final record = OvertimeRecord(
        id: 1,
        date: DateTime(2026, 10, 5),
        startTime: '18:00',
        endTime: '21:00',
        durationMinutes: 180,
        type: '工作日',
        rate: 1.5,
        createdAt: now,
        updatedAt: now,
      );
      expect(WorkCalc.hoursOf(record, settings), closeTo(4.5, 0.0001));
      expect(WorkCalc.amountOf(record, settings), 562.50);
    });
  });

  group('固定加班时薪计算', () {
    const settings = AppSettings(hourlyWage: 50, fixedWage: 60);

    OvertimeRecord fixed({
      int minutes = 180,
      double wage = 0,
      String type = '自定义',
    }) {
      final now = DateTime(2026, 10, 5, 9, 30);
      return OvertimeRecord(
        id: 2,
        date: DateTime(2026, 10, 5),
        startTime: '18:00',
        endTime: '21:00',
        durationMinutes: minutes,
        type: type,
        rate: 3,
        calcMode: CalcModes.fixed,
        fixedWage: wage,
        amount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('固定时薪：金额 = 有效时长 × 固定时薪（不乘倍率）', () {
      // 3 小时 × 60 元 = 180 元，倍率 3 不参与计算
      expect(WorkCalc.hoursOf(fixed(wage: 60), settings), closeTo(3, 0.0001));
      expect(WorkCalc.amountOf(fixed(wage: 60), settings), 180.00);
      expect(WorkCalc.fixedWageOf(fixed(wage: 60), settings), 60);
    });

    test('固定时薪：记录未填时薪时回退到设置默认值', () {
      expect(WorkCalc.fixedWageOf(fixed(), settings), 60);
      expect(WorkCalc.amountOf(fixed(), settings), 180.00);
    });

    test('固定时薪同样受扣除休息时间影响', () {
      const deduct = AppSettings(
        hourlyWage: 50,
        fixedWage: 60,
        deductBreak: true,
        breakMinutes: 30,
      );
      final record = fixed(wage: 60);
      expect(WorkCalc.amountOf(record, deduct), 150.00); // 150 分钟 × 60
      expect(WorkCalc.hoursOf(record, deduct), closeTo(2.5, 0.0001));
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
        calcMode: CalcModes.fixed,
        fixedWage: 88.5,
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
      expect(item.calcMode, CalcModes.fixed);
      expect(item.fixedWage, 88.5);
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

    test('旧版 CSV（无 calcMode 列）按倍率解析', () {
      const text = 'id,date,startTime,endTime,durationMinutes,type,rate,project\n'
          '1,2026-10-05,18:00,21:00,180,工作日,1.5,机房';
      final parsed = RecordCsvService.parse(text);
      expect(parsed, hasLength(1));
      expect(parsed.single.calcMode, CalcModes.rate);
      expect(parsed.single.fixedWage, 0);
      expect(parsed.single.durationMinutes, 180);
    });
  });
}
