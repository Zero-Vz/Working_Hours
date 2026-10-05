import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:working_hours/core/constants.dart';
import 'package:working_hours/data/models/income_item.dart';
import 'package:working_hours/data/models/leave_record.dart';
import 'package:working_hours/data/models/overtime_record.dart';
import 'package:working_hours/ui/records/leave_edit_page.dart';
import 'package:working_hours/ui/records/record_edit_page.dart';
import 'package:working_hours/ui/records/record_list_page.dart';
import 'package:working_hours/ui/settings/income_items_page.dart';
import 'package:working_hours/ui/settings/settings_page.dart';
import 'package:working_hours/ui/stats/stats_page.dart';

/// 页面冒烟测试：确认主要页面可正常渲染、交互不抛异常（含布局溢出）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('working_hours_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OvertimeRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LeaveRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(IncomeItemAdapter());
    }
    final box = await Hive.openBox<OvertimeRecord>(BoxNames.records);
    final settings = await Hive.openBox(BoxNames.settings);
    final leaves = await Hive.openBox<LeaveRecord>(BoxNames.leaves);
    final items = await Hive.openBox<IncomeItem>(BoxNames.incomeItems);

    await settings.putAll(<String, dynamic>{
      'hourlyWage': 50.0,
      'deductBreak': true,
      'breakMinutes': 30,
      'showTotalSalary': true,
      'includeSalaryInTotal': true,
      'monthlySalary': 8700.0,
      'spreadToWorkdays': true,
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final samples = <OvertimeRecord>[
      OvertimeRecord(
        id: 1,
        date: today,
        startTime: '18:00',
        endTime: '21:00',
        durationMinutes: 180,
        type: '工作日',
        rate: 1.5,
        project: '机房割接',
        note: '夜间变更',
        isSettled: false,
        amount: 135,
        createdAt: now,
        updatedAt: now,
      ),
      OvertimeRecord(
        id: 2,
        date: DateTime(now.year, now.month, now.day - 1),
        startTime: '22:00',
        endTime: '02:30',
        durationMinutes: 270,
        type: '休息日',
        rate: 2,
        calcMode: CalcModes.fixed,
        fixedWage: 60,
        project: '版本上线',
        isSettled: true,
        amount: 270,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final record in samples) {
      await box.put(record.id, record);
    }

    final sampleLeaves = <LeaveRecord>[
      LeaveRecord(
        id: 1,
        date: today,
        days: 1,
        type: LeaveTypes.paid,
        reason: '年假',
        createdAt: now,
        updatedAt: now,
      ),
      LeaveRecord(
        id: 2,
        date: today,
        days: 0.5,
        type: LeaveTypes.unpaid,
        reason: '病假',
        deductAmount: 300,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final record in sampleLeaves) {
      await leaves.put(record.id, record);
    }

    final sampleItems = <IncomeItem>[
      IncomeItem(
        id: 1,
        name: '岗位补贴',
        kind: IncomeKinds.income,
        amount: 500,
        createdAt: now,
        updatedAt: now,
      ),
      IncomeItem(
        id: 2,
        name: '社保',
        kind: IncomeKinds.deduct,
        amount: 300,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final item in sampleItems) {
      await items.put(item.id, item);
    }
  });

  tearDownAll(() async {
    // no-op：避免测试进程退出时的挂起
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('记录列表页渲染与筛选切换', (tester) async {
    await pumpPage(tester, const RecordListPage());

    expect(find.text('记工时'), findsOneWidget);
    expect(find.text('新增记录'), findsOneWidget);
    // 默认按月查看，显示当月
    expect(find.textContaining('年'), findsWidgets);

    // 切到“按天”查看
    await tester.tap(find.byTooltip('改为按天查看'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('改为按月查看'), findsOneWidget);

    // 前后翻页不抛异常
    await tester.tap(find.byTooltip('前一天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('后一天'));
    await tester.pumpAndSettle();
  });

  testWidgets('记录列表页加班 / 请假切换', (tester) async {
    await pumpPage(tester, const RecordListPage());

    expect(find.text('加班记录'), findsOneWidget);
    expect(find.text('请假记录'), findsOneWidget);
    expect(find.text('新增记录'), findsOneWidget);

    await tester.tap(find.text('请假记录'));
    await tester.pumpAndSettle();

    expect(find.text('新增请假'), findsOneWidget);
    expect(find.textContaining('理由：年假'), findsOneWidget);
    expect(find.text('不扣工资'), findsWidgets);

    await tester.tap(find.text('加班记录'));
    await tester.pumpAndSettle();
    expect(find.text('新增记录'), findsOneWidget);
  });

  testWidgets('统计页月度 / 年度切换与金额趋势', (tester) async {
    await pumpPage(tester, const StatsPage());

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('月度'), findsOneWidget);
    expect(find.text('年度'), findsOneWidget);
    expect(find.text('月度加班时长'), findsOneWidget);
    expect(find.text('月度折算工时'), findsOneWidget);
    expect(find.text('月度加班费'), findsOneWidget);

    // 总工资卡（含扣增）与请假汇总
    expect(find.text('整月总工资（含扣增）'), findsOneWidget);
    expect(find.text('应发合计'), findsOneWidget);
    expect(find.text('当月请假汇总'), findsOneWidget);

    // 月度：每日金额趋势（折线 + 条形，同一份数据）
    expect(find.textContaining('每日金额趋势 · 折线'), findsOneWidget);
    expect(find.textContaining('每日金额趋势 · 条形'), findsOneWidget);

    await tester.tap(find.text('年度'));
    await tester.pumpAndSettle();
    expect(find.text('全年加班时长'), findsOneWidget);
    expect(find.text('全年折算工时'), findsOneWidget);
    expect(find.text('全年加班费'), findsOneWidget);
    expect(find.text('全年总工资（含扣增）'), findsOneWidget);
    expect(find.text('全年请假汇总'), findsOneWidget);
    expect(find.textContaining('每月金额趋势 · 折线'), findsOneWidget);
    expect(find.textContaining('每月金额趋势 · 条形'), findsOneWidget);

    // 年度前后翻页
    await tester.tap(find.byTooltip('上一年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('回到今年'));
    await tester.pumpAndSettle();
  });

  testWidgets('设置页按功能分组与二级菜单', (tester) async {
    await pumpPage(tester, const SettingsPage());

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('薪资与时薪'), findsOneWidget);
    expect(find.text('计算规则'), findsOneWidget);
    expect(find.text('工资项'), findsOneWidget);
    expect(find.text('统计显示'), findsOneWidget);
    expect(find.text('按时薪'), findsNothing);

    // 数据管理在列表下方，滚动后再断言
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('薪资与时薪'), findsOneWidget);

    await tester.tap(find.text('薪资与时薪'));
    await tester.pumpAndSettle();
    expect(find.text('薪资与时薪'), findsOneWidget);
    expect(find.text('按时薪'), findsOneWidget);
    expect(find.text('按月薪'), findsOneWidget);
    expect(find.text('默认固定加班时薪'), findsOneWidget);

    // 切换到按月薪再切回，保证设置写入正常
    await tester.tap(find.text('按月薪'));
    await tester.pumpAndSettle();
    expect(find.text('月薪'), findsOneWidget);
    await tester.tap(find.text('按时薪'));
    await tester.pumpAndSettle();
  });

  testWidgets('工资项页可管理自定义名称', (tester) async {
    await pumpPage(tester, const IncomeItemsPage());

    expect(find.text('工资项'), findsOneWidget);
    expect(find.text('岗位补贴'), findsOneWidget);
    expect(find.text('社保'), findsOneWidget);
    expect(find.text('新增工资项'), findsWidgets);

    await tester.tap(find.text('岗位补贴'));
    await tester.pumpAndSettle();
    expect(find.text('编辑工资项'), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('新增记录页：类型选择、固定时长与日历自动倍率', (tester) async {
    await pumpPage(tester, const RecordEditPage());

    expect(find.text('新增记录'), findsOneWidget);
    expect(find.text('加班类型'), findsOneWidget);
    expect(find.text('休息时长'), findsOneWidget);

    // 自定义类型才会出现倍率 / 固定时薪编辑
    expect(find.text('按倍率'), findsNothing);
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    expect(find.text('按倍率'), findsOneWidget);
    expect(find.text('按固定时薪'), findsOneWidget);

    // 切换为固定时薪
    await tester.tap(find.text('按固定时薪'));
    await tester.pumpAndSettle();
    expect(find.text('固定加班时薪'), findsOneWidget);

    // 切回起止时间 / 固定时长
    await tester.tap(find.text('固定时长'));
    await tester.pumpAndSettle();
    expect(find.text('结束时间（自动计算）'), findsOneWidget);

    // 打开时长选择弹窗
    await tester.ensureVisible(find.text('加班时长'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加班时长'));
    await tester.pumpAndSettle();
    expect(find.text('选择加班时长'), findsOneWidget);

    final chipInDialog = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('3小时'),
    );
    expect(chipInDialog, findsOneWidget);
    await tester.tap(chipInDialog);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('选择加班时长'), findsNothing);
  });

  testWidgets('新增记录页：单条记录休息时长弹窗', (tester) async {
    await pumpPage(tester, const RecordEditPage());

    await tester.ensureVisible(find.text('休息时长'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('休息时长'));
    await tester.pumpAndSettle();

    expect(find.text('本条记录的休息时长'), findsOneWidget);
    final chip = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('45 分钟'),
    );
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('本条记录的休息时长'), findsNothing);
    expect(find.textContaining('仅本条记录生效'), findsOneWidget);
  });

  testWidgets('新增请假页：带薪 / 无薪与按日薪估算', (tester) async {
    await pumpPage(tester, const LeaveEditPage());

    expect(find.text('新增请假'), findsOneWidget);
    expect(find.text('请假天数'), findsOneWidget);
    expect(find.text('扣工资金额（元）'), findsNothing);

    await tester.tap(find.text('无薪'));
    await tester.pumpAndSettle();
    expect(find.text('扣工资金额（元）'), findsOneWidget);
    expect(find.text('按日薪估算'), findsOneWidget);

    await tester.tap(find.text('按日薪估算'));
    await tester.pumpAndSettle();
    // 时薪 50 → 日薪 = 50 × 8 = 400
    expect(find.text('400.00'), findsOneWidget);

    await tester.tap(find.text('带薪'));
    await tester.pumpAndSettle();
    expect(find.text('扣工资金额（元）'), findsNothing);
    expect(find.text('带薪请假不扣除工资'), findsOneWidget);
  });
}
