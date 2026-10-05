import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/leave_record.dart';
import '../../providers/leaves_provider.dart';
import '../../providers/settings_provider.dart';

/// 新增 / 编辑请假记录（带薪 / 无薪、理由、扣工资）
class LeaveEditPage extends ConsumerStatefulWidget {
  const LeaveEditPage({super.key, this.record});

  /// 为 null 表示新增
  final LeaveRecord? record;

  @override
  ConsumerState<LeaveEditPage> createState() => _LeaveEditPageState();
}

class _LeaveEditPageState extends ConsumerState<LeaveEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _deductController = TextEditingController();

  late DateTime _date;
  late String _type;

  bool get _isEditing => widget.record != null;

  bool get _paid => LeaveTypes.isPaid(_type);

  double get _days => double.tryParse(_daysController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _date = record?.date ?? dateOnly(DateTime.now());
    _type = record?.type ?? LeaveTypes.paid;
    _daysController.text = record == null ? '1' : formatDays(record.days);
    _reasonController.text = record?.reason ?? '';
    _deductController.text =
        record == null ? '' : formatMoney(record.deductAmount);
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    _deductController.dispose();
    super.dispose();
  }

  /// 日薪：月薪 ÷ 21.75，未填月薪则按时薪 × 8
  double get _dailyWage {
    final settings = ref.read(settingsProvider);
    if (settings.useMonthlySalary && settings.monthlySalary > 0) {
      return settings.monthlySalary / kMonthlyPayDays;
    }
    return settings.effectiveHourlyWage * kDailyWorkHours;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = dateOnly(picked));
  }

  void _estimateDeduct() {
    final daily = _dailyWage;
    if (daily <= 0) {
      _showMessage('请先在「设置 → 薪资与时薪」填写月薪或时薪');
      return;
    }
    final value = daily * (_days <= 0 ? 1 : _days);
    setState(() => _deductController.text = formatMoney(value));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final days = _days;
    if (days <= 0) {
      _showMessage('请假天数必须大于 0');
      return;
    }
    var deduct = 0.0;
    if (!_paid) {
      deduct = double.tryParse(_deductController.text.trim()) ?? 0;
      if (deduct < 0) {
        _showMessage('扣工资金额不能为负数');
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final existing = widget.record;

    final record = LeaveRecord(
      id: existing?.id ?? 0,
      date: _date,
      days: days,
      type: _type,
      reason: _reasonController.text.trim(),
      deductAmount: deduct,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(leavesProvider.notifier).upsert(record);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_isEditing ? '已保存修改' : '已新增请假记录')),
      );
  }

  Future<void> _delete() async {
    final record = widget.record;
    if (record == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除请假记录'),
        content: const Text('确定删除这条请假记录吗？'),
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
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(leavesProvider.notifier).delete(record.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已删除记录')));
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑请假' : '新增请假'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _save,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: [
            _sectionTitle(theme, '请假信息'),
            _card(
              scheme,
              children: [
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('日期'),
                  subtitle: Text(
                    '${formatDateCn(_date)} ${weekdayCn(_date)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickDate,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: LeaveTypes.paid,
                              label: Text('带薪'),
                              icon: Icon(Icons.payments_outlined),
                            ),
                            ButtonSegment(
                              value: LeaveTypes.unpaid,
                              label: Text('无薪'),
                              icon: Icon(Icons.beach_access_outlined),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (values) =>
                              setState(() => _type = values.first),
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _daysController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: '请假天数',
                          hintText: '例如 1、0.5',
                          suffixText: '天',
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_view_week_outlined),
                        ),
                        validator: (value) {
                          final parsed =
                              double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return '请输入大于 0 的天数';
                          }
                          if (parsed > 365) return '天数不能超过 365';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final item in const <(String, String)>[
                            ('0.5', '半天'),
                            ('1', '1天'),
                            ('1.5', '1.5天'),
                            ('2', '2天'),
                            ('3', '3天'),
                          ])
                            ActionChip(
                              label: Text(
                                item.$2,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => setState(
                                () => _daysController.text = item.$1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle(theme, '理由'),
            TextFormField(
              controller: _reasonController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '请假理由',
                hintText: '例如：事假 / 病假 / 探亲',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle(theme, '工资'),
            _card(
              scheme,
              children: [
                if (_paid)
                  const ListTile(
                    leading: Icon(Icons.payments_outlined),
                    title: Text('扣工资'),
                    subtitle: Text(
                      '带薪请假不扣除工资',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Text('不扣除'),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextFormField(
                      controller: _deductController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: '扣工资金额（元）',
                        hintText: '填 0 表示不扣除',
                        prefixIcon: Icon(Icons.remove_circle_outline),
                        isDense: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '日薪参考 ¥${formatMoney(_dailyWage)}'
                            '（${_dailyWage <= 0 ? '先设置薪资' : '按 ${formatDays(_days <= 0 ? 1 : _days)} 天 ≈ ¥${formatMoney(_dailyWage * (_days <= 0 ? 1 : _days))}'}）',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _estimateDeduct,
                          icon: const Icon(Icons.calculate_outlined, size: 18),
                          label: const Text('按日薪估算'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? '保存修改' : '保存记录'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, {required List<Widget> children}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
