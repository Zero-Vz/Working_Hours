import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：统计显示（月薪计入总工资 / 均摊到工作日 / 总工资视图）
class StatsSettingsPage extends ConsumerWidget {
  const StatsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // 四张趋势图的独立开关（结构一致，统一构建）
    Widget trendSwitch({
      required bool value,
      required IconData icon,
      required String title,
      required String subtitle,
      required ValueChanged<bool> onChanged,
      bool divider = true,
    }) {
      return Column(
        children: [
          if (divider) settingsDivider,
          SwitchListTile(
            secondary: Icon(icon),
            title: Text(title),
            subtitle: Text(
              value ? subtitle : '已隐藏该趋势图（数据不受影响）',
              style: const TextStyle(fontSize: 12),
            ),
            value: value,
            onChanged: onChanged,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('统计显示')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '统计视图'),
          settingsCard(
            context,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('显示整月总工资'),
                subtitle: Text(
                  settings.showTotalSalary
                      ? '统计页展示整月总工资卡（含扣增），'
                          '金额趋势按总金额绘制'
                      : '统计页仅展示加班记录与加班金额趋势',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.showTotalSalary,
                onChanged: (value) {
                  notifier.setShowTotalSalary(value);
                  _toast(
                    context,
                    value ? '已切换为整月总工资视图' : '已切换为仅加班记录趋势',
                  );
                },
              ),
              settingsDivider,
              SwitchListTile(
                secondary: const Icon(Icons.payments_outlined),
                title: const Text('月薪计入总工资'),
                subtitle: Text(
                  settings.includeSalaryInTotal
                      ? '总工资 = 月薪 ¥${formatMoney(settings.monthlySalary)}'
                          ' + 加班费 + 增项 - 扣项 - 请假扣款'
                      : '总工资不含月薪，仅统计加班与工资项',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.includeSalaryInTotal,
                onChanged: notifier.setIncludeSalaryInTotal,
              ),
              settingsDivider,
              SwitchListTile(
                secondary: const Icon(Icons.calendar_view_day_outlined),
                title: const Text('均摊到每个工作日'),
                subtitle: const Text(
                  '把月薪与固定工资项平均分配到当月每个工作日，'
                  '每日金额趋势才会包含这部分',
                  style: TextStyle(fontSize: 12),
                ),
                value: settings.spreadToWorkdays,
                onChanged: notifier.setSpreadToWorkdays,
              ),
            ],
          ),
          settingsHeader(context, '显示内容'),
          settingsCard(
            context,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.beach_access_outlined),
                title: const Text('显示请假记录'),
                subtitle: Text(
                  settings.showLeaveRecords
                      ? '记录页显示请假分段，统计页显示请假汇总与请假扣款趋势'
                      : '隐藏记录页请假分段与统计页请假汇总、趋势',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.showLeaveRecords,
                onChanged: (value) {
                  notifier.setShowLeaveRecords(value);
                  _toast(
                    context,
                    value ? '已显示请假记录' : '已隐藏请假记录（数据保留）',
                  );
                },
              ),
              settingsDivider,
              SwitchListTile(
                secondary: const Icon(Icons.tune_outlined),
                title: const Text('显示增扣项'),
                subtitle: Text(
                  settings.showIncomeItems
                      ? '统计页显示增扣金额卡与增扣项趋势'
                      : '隐藏统计页增扣金额卡与趋势（总工资明细不受影响）',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.showIncomeItems,
                onChanged: (value) {
                  notifier.setShowIncomeItems(value);
                  _toast(
                    context,
                    value ? '已显示增扣项' : '已隐藏增扣项（数据保留）',
                  );
                },
              ),
            ],
          ),
          settingsHeader(context, '图表样式'),
          settingsCard(
            context,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.bar_chart_rounded),
                title: const Text('趋势用条形图显示'),
                subtitle: Text(
                  settings.useBarChart
                      ? '当前：条形图 · 四张趋势图统一生效'
                      : '当前：折线图 · 四张趋势图统一生效',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.useBarChart,
                onChanged: (value) {
                  notifier.setTrendChartStyle(
                    value ? TrendChartStyles.bar : TrendChartStyles.line,
                  );
                  _toast(
                    context,
                    value ? '趋势图已切换为条形图' : '趋势图已切换为折线图',
                  );
                },
              ),
            ],
          ),
          settingsHeader(context, '趋势显示'),
          settingsCard(
            context,
            children: [
              trendSwitch(
                value: settings.showHoursTrend,
                icon: Icons.timelapse_outlined,
                title: '显示时长趋势',
                subtitle: '按天 / 按月展示有效加班时长',
                onChanged: notifier.setShowHoursTrend,
                divider: false,
              ),
              trendSwitch(
                value: settings.showAmountTrend,
                icon: Icons.payments_outlined,
                title: '显示金额趋势',
                subtitle: '按天 / 按月展示加班费金额',
                onChanged: notifier.setShowAmountTrend,
              ),
              trendSwitch(
                value: settings.showIncomeTrend,
                icon: Icons.tune_outlined,
                title: '显示增扣趋势',
                subtitle: '工资项增项与扣项的净额走势',
                onChanged: notifier.setShowIncomeTrend,
              ),
              trendSwitch(
                value: settings.showLeaveTrend,
                icon: Icons.beach_access_outlined,
                title: '显示请假扣款趋势',
                subtitle: '每天请假扣款金额走势',
                onChanged: notifier.setShowLeaveTrend,
              ),
            ],
          ),
          settingsHeader(context, '计算口径'),
          settingsCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '· 整月总工资 = 月薪（可选）+ 加班费 + 增项 - 扣项 - 请假扣款\n'
                  '· 全年总工资按 12 个月逐月汇总，'
                  '支持在「薪资与时薪 → 按月月薪」单独调整某个月\n'
                  '· 工资项同样按月取值，未单独设置的月份使用默认金额\n'
                  '· 每日金额趋势 = 当天加班费'
                  '（开启均摊时再加上平摊的月薪与工资项），'
                  '不含请假扣款；请假扣款与增扣项各有独立趋势\n'
                  '· 「显示请假 / 增扣项」只控制统计页与记录页的展示，'
                  '不影响总工资的计算口径\n'
                  '· 关闭「显示整月总工资」后，统计只看加班记录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
