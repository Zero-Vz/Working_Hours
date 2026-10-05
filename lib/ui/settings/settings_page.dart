import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/income_items_provider.dart';
import '../../providers/settings_provider.dart';
import 'calc_settings_page.dart';
import 'data_settings_page.dart';
import 'income_items_page.dart';
import 'rate_settings_page.dart';
import 'salary_settings_page.dart';
import 'settings_common.dart';
import 'stats_settings_page.dart';

/// 设置首页：按功能分组，二级菜单进入各设置项
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final extra = ref.watch(incomeExtraTotalProvider);
    final deduct = ref.watch(incomeDeductTotalProvider);

    final salarySubtitle = settings.useMonthlySalary
        ? '月薪 ¥${formatMoney(settings.monthlySalary)} · '
            '时薪 ¥${formatMoney(settings.effectiveHourlyWage)}'
        : '时薪 ¥${formatMoney(settings.hourlyWage)} / 小时';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '薪资'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('薪资与时薪'),
                subtitle: Text(salarySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SalarySettingsPage(),
                  ),
                ),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.percent_outlined),
                title: const Text('默认倍率'),
                subtitle: Text(
                  [
                    for (final type in OvertimeTypes.all)
                      '$type ×${rateText(settings.defaultRateOf(type))}',
                  ].join('　'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RateSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
          settingsHeader(context, '计算与记录'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('计算规则'),
                subtitle: Text(
                  settings.deductBreak
                      ? '扣休息 ${settings.breakMinutes} 分钟 / 条'
                      : '不扣休息 · 按完整时长计算',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CalcSettingsPage(),
                  ),
                ),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('工资项'),
                subtitle: Text(
                  '补贴 / 绩效 ¥${formatMoney(extra)} · '
                  '税费保险 -¥${formatMoney(deduct)} / 月',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const IncomeItemsPage(),
                  ),
                ),
              ),
            ],
          ),
          settingsHeader(context, '统计'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('统计显示'),
                subtitle: Text(
                  settings.showTotalSalary
                      ? '整月总工资（含扣增）'
                      : '仅加班记录趋势',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StatsSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
          settingsHeader(context, '外观'),
          settingsCard(
            context,
            children: [
              for (final item in const <(String, String)>[
                ('system', '跟随系统'),
                ('light', '浅色模式'),
                ('dark', '深色模式'),
              ])
                RadioListTile<String>(
                  title: Text(item.$2),
                  value: item.$1,
                  groupValue: settings.themeMode,
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(settingsProvider.notifier).setThemeMode(value);
                  },
                ),
            ],
          ),
          settingsHeader(context, '数据'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: const Text('数据管理'),
                subtitle: const Text('导出 / 导入 CSV、清空数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DataSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
          settingsHeader(context, '关于'),
          settingsCard(
            context,
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('记工时 v$kAppVersion'),
                subtitle: Text(
                  '纯离线应用：不联网、不登录、不申请任何权限；'
                  '所有数据仅保存在本机。',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
