import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/calc.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/overtime_record.dart';
import '../../providers/filter_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/settings_provider.dart';

/// 新增 / 编辑加班记录
class RecordEditPage extends ConsumerStatefulWidget {
  const RecordEditPage({super.key, this.record});

  /// 为 null 表示新增
  final OvertimeRecord? record;

  @override
  ConsumerState<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends ConsumerState<RecordEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  late DateTime _date;
  late String _start;
  late String _end;
  late String _type;
  double _rate = 1.5;
  bool _compensatory = false;
  bool _settled = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final settings = ref.read(settingsProvider);

    _date = record?.date ?? dateOnly(DateTime.now());
    _start = record?.startTime ?? '18:00';
    _end = record?.endTime ?? '21:00';
    _type = record?.type ?? OvertimeTypes.weekday;
    _rate = record?.rate ?? settings.defaultRateOf(_type);
    _compensatory = record?.isCompensatory ?? false;
    _settled = record?.isSettled ?? false;
    _projectController.text = record?.project ?? settings.defaultProject;
    _noteController.text = record?.note ?? '';
    _rateController.text = _rateText(_rate);
  }

  @override
  void dispose() {
    _projectController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  int get _durationMinutes => calcDurationMinutes(_start, _end);

  bool get _crossDay => isOvernightRange(_start, _end);

  bool get _timeInvalid => _start == _end;

  double get _hours => WorkCalc.convertedHours(
        durationMinutes: _durationMinutes,
        rate: _rate,
        deductBreak: ref.read(settingsProvider).deductBreak,
        breakMinutes: ref.read(settingsProvider).breakMinutes,
        roundToMinute: ref.read(settingsProvider).roundToMinute,
      );

  double get _amount => WorkCalc.money(
        _hours,
        ref.read(settingsProvider).hourlyWage,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final minutes = parseTimeToMinutes(isStart ? _start : _end) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (picked == null) return;
    final value = minutesToTime(picked.hour * 60 + picked.minute);
    setState(() {
      if (isStart) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _selectType(String type) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _type = type;
      _rate = settings.defaultRateOf(type);
      _rateController.text = _rateText(_rate);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (parseTimeToMinutes(_start) == null ||
        parseTimeToMinutes(_end) == null) {
      _showMessage('请选择开始时间与结束时间');
      return;
    }
    if (_timeInvalid) {
      _showMessage('结束时间不能等于开始时间');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);
    final now = DateTime.now();
    final existing = widget.record;

    final record = OvertimeRecord(
      id: existing?.id ?? 0,
      date: _date,
      startTime: _start,
      endTime: _end,
      durationMinutes: _durationMinutes,
      type: _type,
      rate: _rate,
      project: _projectController.text.trim(),
      note: _noteController.text.trim(),
      isCompensatory: _compensatory,
      isSettled: _settled,
      amount: 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    record.amount = WorkCalc.amountOf(record, settings);

    await ref.read(recordsProvider.notifier).upsert(record);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_isEditing ? '已保存修改' : '已新增记录')),
      );
  }

  Future<void> _delete() async {
    final record = widget.record;
    if (record == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定删除这条加班记录吗？'),
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
    await ref.read(recordsProvider.notifier).delete(record.id);
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
    final settings = ref.watch(settingsProvider);
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '新增记录'),
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
            _sectionTitle(theme, '时间'),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
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
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.play_arrow_outlined),
                          title: const Text('开始时间'),
                          subtitle: Text(_start),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.stop_outlined),
                          title: const Text('结束时间'),
                          subtitle: Text(_end),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _timeInvalid
                    ? scheme.errorContainer.withOpacity(0.6)
                    : scheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '时长：${formatDuration(_durationMinutes)}',
                        style: theme.textTheme.titleSmall,
                      ),
                      if (_crossDay) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '跨天 +24h',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeInvalid
                        ? '结束时间不能等于开始时间，请重新选择'
                        : '折算 ${formatHours(_hours)} 小时　预计金额 ¥${formatMoney(_amount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _timeInvalid
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle(theme, '加班类型与倍率'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in OvertimeTypes.all)
                  ChoiceChip(
                    avatar: Icon(
                      OvertimeTypes.iconOf(type),
                      size: 16,
                      color: _type == type
                          ? scheme.onSecondaryContainer
                          : OvertimeTypes.colorOf(type),
                    ),
                    label: Text('$type ×${_rateText(settings.defaultRateOf(type))}'),
                    selected: _type == type,
                    selectedColor: OvertimeTypes.colorOf(type).withOpacity(0.18),
                    onSelected: (_) => _selectType(type),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: '倍率',
                hintText: '例如 1.5',
                prefixIcon: Icon(Icons.percent),
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return '请输入大于 0 的倍率';
                return null;
              },
              onChanged: (value) {
                final parsed = double.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  setState(() => _rate = parsed);
                }
              },
            ),
            const SizedBox(height: 16),

            _sectionTitle(theme, '项目与备注'),
            TextFormField(
              controller: _projectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '项目',
                hintText: '例如：XX 服务器迁移',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final project in projects.take(8))
                    ActionChip(
                      label: Text(project, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(
                        () => _projectController.text = project,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '可选',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle(theme, '状态'),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.swap_horiz_outlined),
                    title: const Text('是否调休'),
                    subtitle: const Text('本次加班以调休方式补偿'),
                    value: _compensatory,
                    onChanged: (value) =>
                        setState(() => _compensatory = value),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    secondary: const Icon(Icons.payments_outlined),
                    title: const Text('是否已结算'),
                    subtitle: const Text('加班费是否已发放'),
                    value: _settled,
                    onChanged: (value) => setState(() => _settled = value),
                  ),
                ],
              ),
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

String _rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
