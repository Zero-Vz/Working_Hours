import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/constants.dart';
import 'package:working_hours/core/utils/time_utils.dart';
import 'package:working_hours/data/csv/leave_csv_service.dart';
import 'package:working_hours/data/models/income_item.dart';
import 'package:working_hours/data/models/leave_record.dart';

void main() {
  final now = DateTime(2026, 10, 5, 9, 30);

  group('请假记录模型', () {
    test('带薪请假不扣工资', () {
      final paid = LeaveRecord(
        id: 1,
        date: DateTime(2026, 10, 5),
        days: 1,
        type: LeaveTypes.paid,
        reason: '事假',
        deductAmount: 500,
        createdAt: now,
        updatedAt: now,
      );
      expect(paid.isPaid, isTrue);
      expect(paid.actualDeduct, 0);
      expect(LeaveTypes.labelOf(paid.type), '带薪');
    });

    test('无薪请假按填写金额扣工资', () {
      final unpaid = LeaveRecord(
        id: 2,
        date: DateTime(2026, 10, 6),
        days: 0.5,
        type: LeaveTypes.unpaid,
        reason: '病假',
        deductAmount: 300,
        createdAt: now,
        updatedAt: now,
      );
      expect(unpaid.isPaid, isFalse);
      expect(unpaid.actualDeduct, 300);
      expect(LeaveTypes.labelOf(unpaid.type), '无薪');
    });

    test('copyWith 保留主键', () {
      final record = LeaveRecord(
        id: 9,
        date: DateTime(2026, 10, 6),
        days: 2,
        reason: '探亲',
        createdAt: now,
        updatedAt: now,
      );
      final updated = record.copyWith(days: 3, reason: '休假');
      expect(updated.id, 9);
      expect(updated.days, 3);
      expect(updated.reason, '休假');
      expect(updated.type, LeaveTypes.paid);
    });
  });

  group('请假记录 CSV', () {
    test('导出后重新解析结果一致', () {
      final source = LeaveRecord(
        id: 5,
        date: DateTime(2026, 10, 5),
        days: 1.5,
        type: LeaveTypes.unpaid,
        reason: '病假,含"引号"',
        deductAmount: 650.5,
        createdAt: now,
        updatedAt: now,
      );

      final text = LeaveCsvService.exportToString([source]);
      final parsed = LeaveCsvService.parse(text);

      expect(parsed, hasLength(1));
      final item = parsed.single;
      expect(formatDateKey(item.date), '2026-10-05');
      expect(item.days, 1.5);
      expect(item.type, LeaveTypes.unpaid);
      expect(item.reason, '病假,含"引号"');
      expect(item.deductAmount, 650.5);
    });

    test('带薪记录导出后仍为不扣除', () {
      final paid = LeaveRecord(
        id: 1,
        date: DateTime(2026, 10, 5),
        days: 1,
        type: LeaveTypes.paid,
        reason: '年假',
        createdAt: now,
        updatedAt: now,
      );
      final parsed = LeaveCsvService.parse(
        LeaveCsvService.exportToString([paid]),
      );
      expect(parsed.single.isPaid, isTrue);
      expect(parsed.single.actualDeduct, 0);
    });

    test('兼容中文类型值与缺失列', () {
      const text = 'id,date,days,type,reason\n'
          '1,2026-10-05,1,无薪,事假';
      final parsed = LeaveCsvService.parse(text);
      expect(parsed, hasLength(1));
      expect(parsed.single.type, LeaveTypes.unpaid);
      expect(parsed.single.deductAmount, 0);
    });

    test('缺少表头时抛出异常', () {
      expect(() => LeaveCsvService.parse('2026-10-05,1'), throwsFormatException);
    });
  });

  group('工资项模型', () {
    IncomeItem item({required String kind, double amount = 100, bool active = true}) {
      return IncomeItem(
        id: 1,
        name: kind == IncomeKinds.deduct ? '社保' : '补贴',
        kind: kind,
        amount: amount,
        active: active,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('增项为正、扣项为负', () {
      expect(item(kind: IncomeKinds.income).signedAmount, 100);
      expect(item(kind: IncomeKinds.deduct).signedAmount, -100);
      expect(item(kind: IncomeKinds.income).isIncome, isTrue);
      expect(item(kind: IncomeKinds.deduct).isDeduct, isTrue);
    });

    test('停用后不计入统计', () {
      expect(
        item(kind: IncomeKinds.income, active: false).signedAmount,
        0,
      );
    });

    test('copyWith 与自定义名称', () {
      final base = item(kind: IncomeKinds.deduct);
      final updated = base.copyWith(name: '公积金', amount: 1200);
      expect(updated.name, '公积金');
      expect(updated.amount, 1200);
      expect(updated.id, base.id);
      expect(IncomeKinds.labelOf(updated.kind), '扣项');
    });
  });
}
