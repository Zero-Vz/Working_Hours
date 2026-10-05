import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：薪资与时薪（时薪 / 月薪、按月月薪调整、默认固定加班时薪）
class SalarySettingsPage extends ConsumerStatefulWidget {
  const SalarySettingsPage({super.key});

  @override
  ConsumerState<SalarySettingsPage> createState() => _SalarySettingsPageState();
}

class _SalarySettingsPageState extends ConsumerState<SalarySettingsPage> {
  /// 按月月薪列表当前展示的年份
  int _year = DateTime.now().year;

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 编辑某个月的月薪；返回「恢复默认」时清除该月的单独设置
  Future<void> _editMonthSalary(int month, AppSettings settings) async {
    final notifier = ref.read(settingsProvider.notifier);
    final has = settings.salaryOverrides.containsKey(yearMonthKey(_year, month));
    final value = await promptMonthAmount(
      context,
      title: '$_year 年 $month 月月薪',
      label: '元 / 月',
      initialValue: formatMoney(
        has ? settings.salaryForYearMonth(_year, month) : settings.monthlySalary,
      ),
      min: 0,
      max: 10000000,
    );
    if (value == null || !mounted) return;
    if (value < 0) {
      notifier.clearSalaryOverride(_year, month);
      _toast('已恢复 $_year 年 $month 月的默认月薪');
      return;
    }
    notifier.setSalaryOverride(_year, month, value);
    _toast('已设置 $_year 年 $month 月月薪，相关金额已重算');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('薪资与时薪')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '薪资录入方式'),
          settingsCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Center(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: SalaryModes.hourly,
                        label: Text('按时薪'),
                      ),
                      ButtonSegment(
                        value: SalaryModes.monthly,
                        label: Text('按月薪'),
                      ),
                    ],
                    selected: {settings.salaryMode},
                    onSelectionChanged: (values) {
                      notifier.setSalaryMode(values.first);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              values.first == SalaryModes.monthly
                                  ? '已切换为按月薪，全部金额已重算'
                                  : '已切换为按时薪，全部金额已重算',
                            ),
                          ),
                        );
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
              if (settings.useMonthlySalary)
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('月薪'),
                  subtitle: Text(
                    '时薪 = 月薪 ÷ 21.75 ÷ 8 '
                    '= ¥${formatMoney(settings.effectiveHourlyWage)} / 小时',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '¥${formatMoney(settings.monthlySalary)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    final value = await promptNumber(
                      context,
                      title: '设置月薪',
                      label: '元 / 月',
                      initialValue: formatMoney(settings.monthlySalary),
                      min: 0,
                      max: 10000000,
                    );
                    if (value == null || !context.mounted) return;
                    notifier.setMonthlySalary(value);
                    _toast('月薪已更新，金额已重算');
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('时薪'),
                  subtitle: const Text('用于计算预计加班费'),
                  trailing: Text(
                    '¥${formatMoney(settings.hourlyWage)} / 小时',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    final value = await promptNumber(
                      context,
                      title: '设置时薪',
                      label: '元 / 小时',
                      initialValue: formatMoney(settings.hourlyWage),
                      min: 0,
                      max: 1000000,
                    );
                    if (value == null || !context.mounted) return;
                    notifier.setHourlyWage(value);
                    _toast('时薪已更新，金额已重算');
                  },
                ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.attach_money_outlined),
                title: const Text('默认固定加班时薪'),
                subtitle: const Text(
                  '记录选择「自定义 + 固定时薪」时的默认值',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '¥${formatMoney(settings.fixedWage)} / 小时',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  final value = await promptNumber(
                    context,
                    title: '默认固定加班时薪',
                    label: '元 / 小时',
                    initialValue: formatMoney(settings.fixedWage),
                    min: 0,
                    max: 1000000,
                  );
                  if (value == null || !context.mounted) return;
                  notifier.setFixedWage(value);
                  _toast('已更新默认固定加班时薪');
                },
              ),
            ],
          ),
          if (settings.useMonthlySalary) ...[
            settingsHeader(context, '按月月薪（可选）'),
            settingsCard(
              context,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '上一年',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _year--),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_year 年',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '下一年',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _year++),
                    ),
                  ],
                ),
                settingsDivider,
                for (var month = 1; month <= 12; month++) ...[
                  if (month > 1) settingsDivider,
                  Builder(
                    builder: (context) {
                      final has = settings.salaryOverrides
                          .containsKey(yearMonthKey(_year, month));
                      final value =
                          settings.salaryForYearMonth(_year, month);
                      return ListTile(
                        leading: Icon(
                          has
                              ? Icons.edit_calendar_outlined
                              : Icons.calendar_month_outlined,
                          color: has ? scheme.primary : null,
                        ),
                        title: Text('$_year 年 $month 月'),
                        subtitle: Text(
                          has
                              ? '已单独设置'
                              : '默认月薪 ¥${formatMoney(settings.monthlySalary)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '¥${formatMoney(value)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: has ? scheme.primary : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => _editMonthSalary(month, settings),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
