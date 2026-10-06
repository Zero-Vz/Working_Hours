import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/salary_range.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：薪资与时薪（时薪 / 月薪、生效起止日期、按月月薪调整、默认固定加班时薪）
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

  /// 新增（index < 0）或编辑某段生效起止日期
  Future<void> _editRange(int index) async {
    final settings = ref.read(settingsProvider);
    final existing = index >= 0 && index < settings.salaryRanges.length
        ? settings.salaryRanges[index]
        : null;
    final result = await showDialog<_RangeResult>(
      context: context,
      builder: (_) => _SalaryRangeDialog(
        initialAmount: settings.monthlySalary,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;

    final ranges = List<SalaryRange>.from(settings.salaryRanges);
    if (result.delete) {
      if (index >= 0 && index < ranges.length) ranges.removeAt(index);
    } else if (result.range != null) {
      if (existing != null) {
        ranges[index] = result.range!;
      } else {
        ranges.add(result.range!);
      }
    }
    ref.read(settingsProvider.notifier).setSalaryRanges(ranges);
    _toast(result.delete ? '已删除该生效区间' : '已保存生效区间，相关金额已重算');
  }

  /// 生效起止日期的单条展示
  Widget _rangeTile(SalaryRange range, int index) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.date_range_outlined,
        color: index.isEven ? scheme.primary : scheme.secondary,
      ),
      title: Text(range.label),
      subtitle: Text(
        '¥${formatMoney(range.amount)} / 月',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _editRange(index),
    );
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
                                  ? '已切换为按月薪，请填写生效起止日期'
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
                  title: const Text('默认月薪'),
                  subtitle: Text(
                    '未被生效起止日期覆盖的月份使用\n'
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
                      title: '设置默认月薪',
                      label: '元 / 月',
                      initialValue: formatMoney(settings.monthlySalary),
                      min: 0,
                      max: 10000000,
                    );
                    if (value == null || !context.mounted) return;
                    notifier.setMonthlySalary(value);
                    _toast('默认月薪已更新，金额已重算');
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
            settingsHeader(context, '生效起止日期'),
            settingsCard(
              context,
              children: [
                for (var i = 0; i < settings.salaryRanges.length; i++) ...[
                  if (i > 0) settingsDivider,
                  _rangeTile(settings.salaryRanges[i], i),
                ],
                if (settings.salaryRanges.isNotEmpty) settingsDivider,
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('添加生效区间'),
                  subtitle: Text(
                    settings.salaryRanges.isEmpty
                        ? '未设置时全部月份使用默认月薪'
                        : '未被区间覆盖的月份使用默认月薪',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _editRange(-1),
                ),
              ],
            ),
            settingsHeader(context, '按月单独修改（可选）'),
            settingsCard(
              context,
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('按月单独修改'),
                  subtitle: const Text(
                    '默认关闭：各月份按「生效起止日期」与默认月薪取值\n'
                    '开启后可展开逐月列表，单独设置某个月的月薪',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.useSalaryOverrides,
                  onChanged: (value) {
                    notifier.setUseSalaryOverrides(value);
                    _toast(
                      value
                          ? '已开启按月单独修改，可展开逐月列表'
                          : '已关闭按月单独修改，按生效起止日期取值',
                    );
                  },
                ),
                if (settings.useSalaryOverrides) ...[
                  settingsDivider,
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
                        final range = settings
                            .salaryRangeAt(DateTime(_year, month, 15));
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
                                : range != null
                                    ? '生效区间 ${range.label}'
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
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 生效起止日期区间的编辑结果
class _RangeResult {
  const _RangeResult.save(SalaryRange this.range) : delete = false;

  const _RangeResult.delete() : range = null, delete = true;

  final SalaryRange? range;
  final bool delete;
}

/// 生效起止日期区间弹窗（新增与编辑共用）
class _SalaryRangeDialog extends StatefulWidget {
  const _SalaryRangeDialog({required this.initialAmount, this.existing});

  /// 新增时的默认月薪
  final double initialAmount;

  final SalaryRange? existing;

  @override
  State<_SalaryRangeDialog> createState() => _SalaryRangeDialogState();
}

class _SalaryRangeDialogState extends State<_SalaryRangeDialog> {
  late DateTime _start;
  DateTime? _end;

  /// 是否一直生效到至今
  late bool _openEnded;

  late final TextEditingController _amount;
  String? _error;

  static String _fmt(DateTime value) =>
      '${value.year}-${pad2(value.month)}-${pad2(value.day)}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    _start = existing?.start ?? DateTime(now.year, now.month, 1);
    _end = existing?.end;
    _openEnded = existing == null || existing.end == null;
    _amount = TextEditingController(
      text: formatMoney(existing?.amount ?? widget.initialAmount),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
    final current =
        isStart ? _start : (_end ?? _start.add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    final day = dateOnly(picked);
    setState(() {
      if (isStart) {
        _start = day;
      } else {
        _end = day;
      }
      _error = null;
    });
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = '请输入有效金额');
      return;
    }
    if (!_openEnded && _end == null) {
      setState(() => _error = '请选择生效结束日期');
      return;
    }
    final end = _openEnded ? null : _end;
    if (end != null && dateOnly(end).isBefore(dateOnly(_start))) {
      setState(() => _error = '结束日期不能早于起始日期');
      return;
    }
    Navigator.of(context).pop(
      _RangeResult.save(SalaryRange(start: _start, end: end, amount: amount)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? '添加生效区间' : '编辑生效区间'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('生效起始日期'),
              subtitle: Text(_fmt(_start)),
              onTap: () => _pick(isStart: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('持续生效（至今）'),
              value: _openEnded,
              onChanged: (value) => setState(() {
                _openEnded = value;
                if (value) _end = null;
                _error = null;
              }),
            ),
            if (!_openEnded)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop_outlined),
                title: const Text('生效结束日期'),
                subtitle: Text(_end == null ? '请点击选择' : _fmt(_end!)),
                onTap: () => _pick(isStart: false),
              ),
            const SizedBox(height: 4),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: '月薪',
                prefixText: '¥ ',
                suffixText: '/ 月',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _RangeResult.delete()),
            child: Text(
              '删除',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
