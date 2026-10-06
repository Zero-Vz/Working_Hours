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
import 'package:working_hours/ui/settings/stats_settings_page.dart';
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

  testWidgets('统计页月度 / 年度切换与时长金额趋势', (tester) async {
    await pumpPage(tester, const StatsPage());

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('月度'), findsOneWidget);
    expect(find.text('年度'), findsOneWidget);
    expect(find.text('月度加班时长'), findsOneWidget);
    expect(find.text('月度增扣金额'), findsOneWidget);
    expect(find.text('月度加班费'), findsOneWidget);

    // 总工资卡（含扣增）与请假汇总
    expect(find.text('整月总工资（含扣增）'), findsOneWidget);
    expect(find.text('应发合计'), findsOneWidget);
    expect(find.text('当月请假汇总'), findsOneWidget);

    // 月度：时长 / 金额 / 增扣项 / 请假扣款，全部为折线图且无条形图
    expect(find.textContaining('每日时长趋势'), findsOneWidget);
    expect(find.textContaining('每日金额趋势'), findsOneWidget);
    expect(find.textContaining('每日增扣金额趋势'), findsOneWidget);
    expect(find.textContaining('每日请假扣款趋势'), findsOneWidget);
    expect(find.textContaining('条形'), findsNothing);
    expect(find.textContaining('回到本月'), findsNothing);

    await tester.tap(find.text('年度'));
    await tester.pumpAndSettle();
    expect(find.text('全年加班时长'), findsOneWidget);
    expect(find.text('全年增扣金额'), findsOneWidget);
    expect(find.text('全年加班费'), findsOneWidget);
    expect(find.text('全年总工资（含扣增）'), findsOneWidget);
    expect(find.text('全年请假汇总'), findsOneWidget);
    expect(find.textContaining('每月时长趋势'), findsOneWidget);
    expect(find.textContaining('每月金额趋势'), findsOneWidget);

    // 年度前后翻页
    await tester.tap(find.byTooltip('上一年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一年'));
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

    expect(find.text('月薪'), findsNothing);

    // 切换到按月薪：默认按「生效起止日期」录入，逐月列表默认隐藏
    await tester.tap(find.text('按月薪'));
    await tester.pumpAndSettle();
    expect(find.text('默认月薪'), findsOneWidget);
    expect(find.text('生效起止日期'), findsOneWidget);
    expect(find.text('添加生效区间'), findsOneWidget);
    expect(find.text('按月单独修改'), findsOneWidget);
    expect(find.text('2026 年 1 月'), findsNothing);

    // 展开后逐月列表可见
    final monthlySwitch = find.byType(Switch).last;
    await tester.ensureVisible(monthlySwitch);
    await tester.pumpAndSettle();
    await tester.tap(monthlySwitch);
    await tester.pumpAndSettle();
    expect(find.text('2026 年 1 月'), findsOneWidget);

    await tester.tap(find.text('按时薪'));
    await tester.pumpAndSettle();
  });

  testWidgets('设置页默认倍率为独立二级菜单', (tester) async {
    await pumpPage(tester, const SettingsPage());

    expect(find.text('默认倍率'), findsOneWidget);
    await tester.ensureVisible(find.text('默认倍率'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认倍率'));
    await tester.pumpAndSettle();

    expect(find.text('默认倍率'), findsOneWidget);
    expect(find.textContaining('默认倍率 · 工作日'), findsOneWidget);
    // 倍率统一保留两位小数，长度一致
    expect(find.text('×1.50'), findsOneWidget);
    expect(find.text('×2.00'), findsOneWidget);
    expect(find.text('×3.00'), findsOneWidget);
    expect(find.text('×1.00'), findsOneWidget);
  });

  testWidgets('设置页节假日数据入口与关于区块', (tester) async {
    await pumpPage(tester, const SettingsPage());

    // 节假日数据二级菜单（内置 2025、2026 年）
    await tester.ensureVisible(find.text('节假日数据'));
    await tester.pumpAndSettle();
    expect(find.text('节假日数据'), findsOneWidget);
    expect(find.textContaining('内置 2025、2026 年'), findsOneWidget);

    await tester.tap(find.text('节假日数据'));
    await tester.pumpAndSettle();
    expect(find.text('联网更新'), findsOneWidget);
    expect(find.text('从文件导入'), findsOneWidget);
    expect(find.text('导出当前数据'), findsOneWidget);
    expect(find.text('更新地址'), findsOneWidget);
    // 仍是内置数据时不出「恢复内置」入口
    expect(find.text('恢复内置数据'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 关于：项目主页、开发者、检查软件更新
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('项目主页'), findsOneWidget);
    expect(find.text('开发者 $kDeveloperName'), findsOneWidget);
    expect(find.text('检查软件更新'), findsOneWidget);
    expect(find.text('记工时 v$kAppVersion'), findsOneWidget);
  });

  testWidgets('统计显示页：图表样式与四张趋势开关', (tester) async {
    await pumpPage(tester, const StatsSettingsPage());

    // 滚到图表样式 / 趋势显示分组
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('趋势用条形图显示'), findsOneWidget);
    expect(find.text('显示时长趋势'), findsOneWidget);
    expect(find.text('显示金额趋势'), findsOneWidget);
    expect(find.text('显示增扣趋势'), findsOneWidget);
    expect(find.text('显示请假扣款趋势'), findsOneWidget);

    // 关闭「显示时长趋势」，统计页应不再渲染该趋势卡
    await tester.tap(find.widgetWithText(SwitchListTile, '显示时长趋势'));
    await tester.pumpAndSettle();

    await pumpPage(tester, const StatsPage());
    expect(find.textContaining('每日时长趋势'), findsNothing);
    expect(find.textContaining('每日金额趋势'), findsOneWidget);

    // 恢复开关，避免影响后续用例
    await pumpPage(tester, const StatsSettingsPage());
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '显示时长趋势'));
    await tester.pumpAndSettle();

    // 趋势卡标题右侧可在折线 / 条形之间一键切换
    await pumpPage(tester, const StatsPage());
    expect(find.textContaining('每日时长趋势'), findsOneWidget);
    final toBar = find.byTooltip('改为条形图');
    expect(toBar, findsWidgets);
    await tester.ensureVisible(toBar.first);
    await tester.pumpAndSettle();
    await tester.tap(toBar.first);
    await tester.pumpAndSettle();
    final toLine = find.byTooltip('改为折线图');
    expect(toLine, findsWidgets);
    await tester.ensureVisible(toLine.first);
    await tester.pumpAndSettle();
    await tester.tap(toLine.first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('改为条形图'), findsWidgets);
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

    // 四个类型共用同一个信息框；自定义通过点击弹窗修改参数
    expect(find.text('按倍率'), findsNothing);
    expect(find.textContaining('倍率在设置中修改'), findsOneWidget);
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    expect(find.textContaining('点击修改'), findsOneWidget);
    expect(find.textContaining('固定时薪 ¥'), findsNothing);

    await tester.tap(find.textContaining('点击修改'));
    await tester.pumpAndSettle();
    expect(find.text('按倍率'), findsOneWidget);
    expect(find.text('按固定时薪'), findsOneWidget);

    // 切换为固定时薪并填写
    await tester.tap(find.text('按固定时薪'));
    await tester.pumpAndSettle();
    expect(find.text('固定加班时薪'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '60',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('按倍率'), findsNothing);
    expect(find.textContaining('固定时薪 ¥60.00/小时'), findsOneWidget);

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

    // 带薪假默认不扣除，但同样提供扣款输入与比例快捷选择
    expect(find.text('扣工资金额（元）'), findsOneWidget);
    expect(find.text('按日薪估算'), findsOneWidget);
    expect(find.text('不扣除'), findsOneWidget);

    await tester.tap(find.text('无薪'));
    await tester.pumpAndSettle();
    expect(find.text('扣工资金额（元）'), findsOneWidget);
    expect(find.text('按日薪估算'), findsOneWidget);

    // 工资区在页面下方，先滚动到可视区域
    await tester.ensureVisible(find.text('按日薪估算'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('按日薪估算'));
    await tester.pumpAndSettle();
    // 时薪 50 → 日薪 = 50 × 8 = 400
    expect(find.text('400.00'), findsOneWidget);

    // 快捷比例：扣 50% / 不扣除
    await tester.tap(find.text('扣 50%'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '200.00'), findsOneWidget);

    await tester.tap(find.text('不扣除'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '0'), findsOneWidget);

    await tester.ensureVisible(find.text('带薪'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('带薪'));
    await tester.pumpAndSettle();
    expect(find.text('扣工资金额（元）'), findsOneWidget);
  });
}
