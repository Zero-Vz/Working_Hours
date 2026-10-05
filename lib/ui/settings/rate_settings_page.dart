import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：各加班类型默认倍率
class RateSettingsPage extends ConsumerWidget {
  const RateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('默认倍率')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
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
                      subtitle: Text(
                        type == OvertimeTypes.custom
                            ? '新增记录选择「自定义」时的默认值'
                            : '按日历自动带出该类型的默认值',
                        style: const TextStyle(fontSize: 12),
                      ),
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
                        notifier.setRateFor(type, value);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text('已更新 $type 默认倍率')),
                          );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
          settingsHeader(context, '说明'),
          settingsCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '· 倍率统一保留两位小数显示（如 1.50、2.00、3.00）\n'
                  '· 记录页只读这里的默认倍率，仅「自定义」类型可在记录里单独修改\n'
                  '· 修改后新增记录立即生效，历史记录保留当时填写的倍率',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
