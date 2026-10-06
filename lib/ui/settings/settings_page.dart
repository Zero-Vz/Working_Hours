import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/holiday_store.dart';
import '../../data/update_check_service.dart';
import '../../providers/income_items_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/version_provider.dart';
import 'calc_settings_page.dart';
import 'data_settings_page.dart';
import 'holidays_settings_page.dart';
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

    // 关于页展示的版本：优先取 APK manifest 中的 versionName
    final version = ref.watch(appVersionProvider).valueOrNull ?? kAppVersion;

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
                // 两行两列，避免四个倍率挤在一行换出孤字
                subtitle: Text(
                  [
                    for (var i = 0; i < OvertimeTypes.all.length; i += 2)
                      [
                        for (final type in OvertimeTypes.all.skip(i).take(2))
                          '$type ×${rateText(settings.defaultRateOf(type))}',
                      ].join('　'),
                  ].join('\n'),
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
                // 按增 / 扣拆成两行，避免折行留下孤字
                subtitle: Text(
                  '增项：补贴 / 绩效 ¥${formatMoney(extra)}\n'
                  '扣项：税费保险 -¥${formatMoney(deduct)} / 月',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const IncomeItemsPage(),
                  ),
                ),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.celebration_outlined),
                title: const Text('节假日数据'),
                subtitle: Text(
                  '内置 ${HolidayStore.yearsText} 年 · 可联网更新或导入',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HolidaysSettingsPage(),
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
              ListTile(
                leading: const Icon(Icons.rocket_launch_outlined),
                title: const Text('项目主页'),
                subtitle: const Text('github.com/Zero-Vz/Working_Hours'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openExternalUrl(context, kRepoUrl),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: const Text('开发者 $kDeveloperName'),
                subtitle: const Text('开源免费 · 功能建议与问题反馈请在项目主页提交'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openExternalUrl(context, kDeveloperUrl),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('检查软件更新'),
                subtitle: Text('当前 v$version · 更新源 GitHub Releases'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _checkForUpdate(context, ref),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('记工时 v$version'),
                subtitle: const Text(
                  '离线优先 · 数据仅保存在本机\n'
                  '联网仅用于：更新节假日数据、检查软件更新',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 打开外部链接，失败时给出提示
Future<void> _openExternalUrl(BuildContext context, String url) async {
  final ok = await openExternalUrl(url);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未能打开链接，请稍后重试')),
    );
  }
}

/// 检查软件更新：成功弹结果，失败可直接修改更新地址
Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('正在检查更新…')),
  );

  try {
    final info = await UpdateCheckService.check(
      ref.read(settingsProvider).releaseApiUrl,
    );
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();

    // 本机版本以 APK manifest 为准，避免与常量不同步导致误判
    final local = await ref.read(appVersionProvider.future);
    if (!context.mounted) return;
    final newer = UpdateCheckService.isNewer(info.version, local);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(newer ? '发现新版本 v${info.version}' : '已是最新版本'),
        content: Text(
          newer
              ? '当前 v$local → 新版 v${info.version}\n\n'
                  '${info.notes.isEmpty ? '前往发布页查看更新说明。' : info.notes}'
              : '当前 v$local 已是最新版本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(newer ? '关闭' : '确定'),
          ),
          if (newer)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openExternalUrl(context, info.url);
              },
              child: const Text('前往下载页'),
            ),
        ],
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    final settings = ref.read(settingsProvider);

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('检查更新失败'),
        content: Text(
          '$error\n\n当前更新地址：\n${settings.releaseApiUrl}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('edit'),
            child: const Text('修改地址'),
          ),
        ],
      ),
    );
    if (action == 'edit' && context.mounted) {
      final next = await promptText(
        context,
        title: '更新地址',
        label: 'GitHub Releases 接口地址',
        initialValue: settings.releaseApiUrl,
      );
      if (next != null && context.mounted) {
        ref.read(settingsProvider.notifier).setReleaseApiUrl(next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新地址已保存')),
        );
      }
    }
  }
}
