import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：薪资与时薪（时薪 / 月薪、默认倍率、默认固定加班时薪）
class SalarySettingsPage extends ConsumerWidget {
  const SalarySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    _toast(context, '月薪已更新，金额已重算');
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
                    _toast(context, '时薪已更新，金额已重算');
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
                  _toast(context, '已更新默认固定加班时薪');
                },
              ),
            ],
          ),
          settingsHeader(context, '各类型默认倍率'),
          settingsCard(
            context,
            children: [
              for (var i = 0; i < OvertimeTypes.all.length; i++) ...[
                if (i > 0) settingsDivider,
                Builder(
                  builder: (context) {
                    final type = OvertimeTypes.all[i];
                    return ListTile(
                      leading: Icon(OvertimeTypes.iconOf(type)),
                      title: Text('默认倍率 · $type'),
                      trailing: Text(
                        '×${rateText(settings.defaultRateOf(type))}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () async {
                        final value = await promptNumber(
                          context,
                          title: '默认倍率 · $type',
                          label: '倍率',
                          initialValue: rateText(
                            settings.defaultRateOf(type),
                          ),
                          min: 0.01,
                          max: 100,
                        );
                        if (value == null || !context.mounted) return;
                        ref
                            .read(settingsProvider.notifier)
                            .setRateFor(type, value);
                        _toast(context, '已更新 $type 默认倍率');
                      },
                    );
                  },
                ),
              ],
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
