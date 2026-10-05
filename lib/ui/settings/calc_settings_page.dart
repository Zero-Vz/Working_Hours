import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：计算规则（休息时间、取整、默认项目）
class CalcSettingsPage extends ConsumerWidget {
  const CalcSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('计算规则')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '休息时间'),
          settingsCard(
            context,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.coffee_outlined),
                title: const Text('扣除休息时间'),
                subtitle: Text(
                  settings.deductBreak
                      ? '每条记录默认扣除 ${settings.breakMinutes} 分钟，'
                          '可为单条记录单独设置休息时长'
                      : '按完整时长计算',
                  style: const TextStyle(fontSize: 12),
                ),
                value: settings.deductBreak,
                onChanged: (value) {
                  notifier.setDeductBreak(value);
                  _toast(context, value ? '已开启休息时间扣除' : '已关闭休息时间扣除');
                },
              ),
              if (settings.deductBreak) ...[
                settingsDivider,
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('默认休息时长'),
                  subtitle: const Text(
                    '新增记录默认使用该时长，可在记录内单独调整',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Text('${settings.breakMinutes} 分钟'),
                  onTap: () async {
                    final value = await promptNumber(
                      context,
                      title: '默认休息时长',
                      label: '分钟',
                      initialValue: '${settings.breakMinutes}',
                      decimal: false,
                      min: 0,
                      max: 1440,
                    );
                    if (value == null || !context.mounted) return;
                    notifier.setBreakMinutes(value.round());
                    _toast(context, '已更新默认休息时长');
                  },
                ),
              ],
            ],
          ),
          settingsHeader(context, '计算方式'),
          settingsCard(
            context,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.adjust_outlined),
                title: const Text('四舍五入到分钟'),
                subtitle: const Text('折算工时先按分钟取整再计算金额'),
                value: settings.roundToMinute,
                onChanged: notifier.setRoundToMinute,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('默认项目'),
                trailing: Text(
                  settings.defaultProject.isEmpty
                      ? '未设置'
                      : settings.defaultProject,
                ),
                onTap: () async {
                  final value = await promptText(
                    context,
                    title: '默认项目',
                    label: '项目名称',
                    initialValue: settings.defaultProject,
                  );
                  if (value == null || !context.mounted) return;
                  notifier.setDefaultProject(value.trim());
                },
              ),
            ],
          ),
          settingsHeader(context, '说明'),
          settingsCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '· 起止时间：时长 = 结束 - 开始，跨天自动 +24 小时\n'
                  '· 固定时长：填写的是实际加班时长，'
                  '开启扣休息后结束时间 = 开始 + 时长 + 休息\n'
                  '· 折算工时 = 有效时长 × 倍率；金额 = 折算工时 × 时薪\n'
                  '· 选择「固定时薪」的记录不乘倍率，'
                  '金额 = 有效时长 × 固定时薪',
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
