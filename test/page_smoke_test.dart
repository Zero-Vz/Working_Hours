import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:working_hours/core/constants.dart';
import 'package:working_hours/data/models/overtime_record.dart';
import 'package:working_hours/ui/records/record_edit_page.dart';
import 'package:working_hours/ui/records/record_list_page.dart';
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
    final box = await Hive.openBox<OvertimeRecord>(BoxNames.records);
    final settings = await Hive.openBox(BoxNames.settings);
    await settings.put('hourlyWage', 50.0);

    final now = DateTime.now();
    final samples = <OvertimeRecord>[
      OvertimeRecord(
        id: 1,
        date: DateTime(now.year, now.month, now.day),
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

  testWidgets('统计页月度 / 年度切换', (tester) async {
    await pumpPage(tester, const StatsPage());

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('月度'), findsOneWidget);
    expect(find.text('年度'), findsOneWidget);
    expect(find.text('当月加班时长'), findsOneWidget);
    expect(find.text('当月折算工时'), findsOneWidget);
    expect(find.text('当月加班费'), findsOneWidget);

    await tester.tap(find.text('年度'));
    await tester.pumpAndSettle();
    expect(find.text('全年加班时长'), findsOneWidget);
    expect(find.text('全年折算工时'), findsOneWidget);
    expect(find.text('全年加班费'), findsOneWidget);

    // 年度前后翻页
    await tester.tap(find.byTooltip('上一年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('回到今年'));
    await tester.pumpAndSettle();
  });

  testWidgets('设置页渲染', (tester) async {
    await pumpPage(tester, const SettingsPage());

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('按时薪'), findsOneWidget);
    expect(find.text('按月薪'), findsOneWidget);
    expect(find.text('扣除休息时间'), findsOneWidget);
    expect(find.text('默认固定加班时薪'), findsOneWidget);

    // 切换到按月薪
    await tester.tap(find.text('按月薪'));
    await tester.pumpAndSettle();
    expect(find.text('月薪'), findsOneWidget);
  });

  testWidgets('新增记录页：类型选择、固定时长与日历自动倍率', (tester) async {
    await pumpPage(tester, const RecordEditPage());

    expect(find.text('新增记录'), findsOneWidget);
    expect(find.text('加班类型'), findsOneWidget);

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
}
