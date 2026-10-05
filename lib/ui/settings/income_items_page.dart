import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/income_item.dart';
import '../../providers/income_items_provider.dart';
import 'settings_common.dart';

/// 二级设置：工资项（自定义补贴 / 绩效 / 税费 / 保险等）
///
/// 金额为每月固定金额，按月计入「整月总工资」。
class IncomeItemsPage extends ConsumerStatefulWidget {
  const IncomeItemsPage({super.key});

  @override
  ConsumerState<IncomeItemsPage> createState() => _IncomeItemsPageState();
}

class _IncomeItemsPageState extends ConsumerState<IncomeItemsPage> {
  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 新增 / 编辑工资项
  Future<void> _editItem({IncomeItem? existing}) async {
    var name = existing?.name ?? '';
    var kind = existing?.kind ?? IncomeKinds.income;
    var amount = existing?.amount ?? 0.0;
    var active = existing?.active ?? true;
    final overrides = Map<String, double>.from(
      existing?.monthlyOverrides ?? const <String, double>{},
    );
    var overrideYear = DateTime.now().year;

    final nameController = TextEditingController(text: name);
    final amountController = TextEditingController(
      text: existing == null ? '' : formatMoney(amount),
    );
    String? nameError;
    String? amountError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            name = nameController.text.trim();
            final parsed = double.tryParse(amountController.text.trim());
            if (name.isEmpty) {
              setDialogState(() => nameError = '请输入名称');
              return;
            }
            if (parsed == null || parsed < 0) {
              setDialogState(() => amountError = '请输入不小于 0 的金额');
              return;
            }
            amount = parsed;
            Navigator.of(dialogContext).pop(true);
          }

          return AlertDialog(
            title: Text(existing == null ? '新增工资项' : '编辑工资项'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: existing == null,
                    decoration: InputDecoration(
                      labelText: '名称',
                      hintText: '例如：个税 / 社保 / 补贴',
                      errorText: nameError,
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() => nameError = null),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in const <(String, String)>[
                        ('个人所得税', 'deduct'),
                        ('社保', 'deduct'),
                        ('公积金', 'deduct'),
                        ('岗位补贴', 'income'),
                        ('绩效奖金', 'income'),
                        ('餐补', 'income'),
                      ])
                        ActionChip(
                          label: Text(
                            item.$1,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => setDialogState(() {
                            nameController.text = item.$1;
                            kind = item.$2;
                            nameError = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: IncomeKinds.income,
                        label: Text('增项（收入）'),
                      ),
                      ButtonSegment(
                        value: IncomeKinds.deduct,
                        label: Text('扣项（支出）'),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (values) =>
                        setDialogState(() => kind = values.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: '每月金额（元）',
                      errorText: amountError,
                      isDense: true,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) => setDialogState(() => amountError = null),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    IncomeKinds.hintOf(kind),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text(
                      '按月单独设置（未设置的月份使用默认金额）',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '上一年',
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: () =>
                              setDialogState(() => overrideYear--),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$overrideYear 年',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '下一年',
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: () =>
                              setDialogState(() => overrideYear++),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var month = 1; month <= 12; month++)
                          ActionChip(
                            avatar: overrides.containsKey(
                              yearMonthKey(overrideYear, month),
                            )
                                ? const Icon(Icons.edit_outlined, size: 14)
                                : null,
                            label: Text(
                              overrides.containsKey(
                                yearMonthKey(overrideYear, month),
                              )
                                  ? '$month月 '
                                      '¥${formatMoney(overrides[yearMonthKey(overrideYear, month)]!)}'
                                  : '$month月 默认',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final key =
                                  yearMonthKey(overrideYear, month);
                              final value = await promptMonthAmount(
                                context,
                                title: '$overrideYear 年 $month 月金额',
                                label: '金额（元）',
                                initialValue: formatMoney(
                                  overrides[key] ?? amount,
                                ),
                                min: 0,
                                max: 10000000,
                              );
                              if (value == null) return;
                              setDialogState(() {
                                if (value < 0) {
                                  overrides.remove(key);
                                } else {
                                  overrides[key] = value;
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  if (existing != null) ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('启用'),
                      subtitle: const Text(
                        '停用后保留条目但不计入统计',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(onPressed: submit, child: const Text('保存')),
            ],
          );
        },
      ),
    );
    // 控制器随弹窗闭包回收：弹窗退出动画结束前销毁它会触发框架断言
    if (saved != true) return;

    final now = DateTime.now();
    final item = (existing ?? IncomeItem(id: 0, name: '', createdAt: now, updatedAt: now))
        .copyWith(
      name: name,
      kind: kind,
      amount: amount,
      active: active,
      monthlyOverrides: overrides,
    );
    await ref.read(incomeItemsProvider.notifier).upsert(item);
    _toast(existing == null ? '已新增工资项「$name」' : '已更新「$name」');
  }

  Future<void> _delete(IncomeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除工资项'),
        content: Text('确定删除「${item.name}」吗？删除后不再计入统计。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(incomeItemsProvider.notifier).delete(item.id);
    _toast('已删除「${item.name}」');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(incomeItemsProvider);
    final extra = ref.watch(incomeExtraTotalProvider);
    final deduct = ref.watch(incomeDeductTotalProvider);

    final incomes = items.where((item) => item.isIncome).toList();
    final outgoes = items.where((item) => item.isDeduct).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('工资项'),
        actions: [
          IconButton(
            tooltip: '新增工资项',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _editItem(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  '增项合计 ¥${formatMoney(extra)} / 月',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IncomeKinds.colorOf(IncomeKinds.income),
                  ),
                ),
                Text(
                  '扣项合计 ¥${formatMoney(deduct)} / 月',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IncomeKinds.colorOf(IncomeKinds.deduct),
                  ),
                ),
                Text(
                  '净额 ¥${formatMoney(extra - deduct)} / 月',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          settingsHeader(context, '增项（补贴 / 绩效…）'),
          if (incomes.isEmpty)
            _emptyCard(context, '还没有增项，点击右上角新增')
          else
            settingsCard(
              context,
              children: [
                for (var i = 0; i < incomes.length; i++) ...[
                  if (i > 0) settingsDivider,
                  _itemTile(incomes[i]),
                ],
              ],
            ),
          settingsHeader(context, '扣项（税费 / 保险…）'),
          if (outgoes.isEmpty)
            _emptyCard(context, '还没有扣项，点击右上角新增')
          else
            settingsCard(
              context,
              children: [
                for (var i = 0; i < outgoes.length; i++) ...[
                  if (i > 0) settingsDivider,
                  _itemTile(outgoes[i]),
                ],
              ],
            ),
          settingsHeader(context, '说明'),
          _emptyCard(
            context,
            '工资项默认按「每月固定金额」参与统计，也可在编辑时按月单独设置'
            '（调薪、浮动绩效的月份），未设置的月份仍使用默认金额。\n'
            '开启「统计显示整月总工资」后，增项加、扣项减，'
            '计入整月总工资与月度 / 年度金额趋势。',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(),
        icon: const Icon(Icons.add),
        label: const Text('新增工资项'),
      ),
    );
  }

  Widget _itemTile(IncomeItem item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = IncomeKinds.colorOf(item.kind);

    return ListTile(
      leading: Icon(IncomeKinds.iconOf(item.kind), color: color),
      title: Text(
        item.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: item.active ? null : scheme.outline,
        ),
      ),
      subtitle: Text(
        item.active
            ? '${IncomeKinds.labelOf(item.kind)} · '
                '¥${formatMoney(item.amount)} / 月'
                '${item.monthlyOverrides.isEmpty ? '' : ' · 按月调整 ${item.monthlyOverrides.length} 个月'}'
            : '已停用（不计入统计）',
        style: TextStyle(
          fontSize: 12,
          color: item.active ? scheme.onSurfaceVariant : scheme.outline,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editItem(existing: item),
          ),
          IconButton(
            tooltip: '删除',
            icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
            onPressed: () => _delete(item),
          ),
        ],
      ),
      onTap: () => _editItem(existing: item),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
      ),
    );
  }
}
