import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/holidays.dart';
import '../../core/utils/calc.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/app_settings.dart';
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
  final TextEditingController _fixedWageController = TextEditingController();

  late DateTime _date;
  late String _start;
  late String _end;
  late String _type;
  late double _rate;
  late String _calcMode;
  late double _fixedWage;

  /// true：按开始 / 结束时间；false：按固定时长
  late bool _byRange;

  /// 固定时长模式下的时长（分钟）
  late int _fixedDuration;

  /// 类型与倍率是否由日历自动带出
  bool _autoFromCalendar = false;

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
    _calcMode = CalcModes.normalize(record?.calcMode);
    _fixedWage =
        (record?.fixedWage ?? 0) > 0 ? record!.fixedWage : settings.fixedWage;
    _byRange = true;
    _fixedDuration =
        record?.durationMinutes ?? calcDurationMinutes(_start, _end);
    if (_fixedDuration <= 0 || _fixedDuration >= 1440) _fixedDuration = 180;
    _compensatory = record?.isCompensatory ?? false;
    _settled = record?.isSettled ?? false;
    _projectController.text = record?.project ?? settings.defaultProject;
    _noteController.text = record?.note ?? '';
    _rateController.text = _rateText(_rate);
    _fixedWageController.text = formatMoney(_fixedWage);

    if (record == null) {
      // 新增：按日历自动选择类型与倍率
      _applyCalendarDefaults(_date);
    }
  }

  @override
  void dispose() {
    _projectController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    _fixedWageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 计算预览

  int get _durationMinutes =>
      _byRange ? calcDurationMinutes(_start, _end) : _fixedDuration;

  bool get _crossDay => isOvernightRange(_start, _end);

  bool get _timeInvalid => _byRange && _start == _end;

  int get _effectiveMinutes => WorkCalc.effectiveMinutes(
        _durationMinutes,
        deductBreak: ref.read(settingsProvider).deductBreak,
        breakMinutes: ref.read(settingsProvider).breakMinutes,
      );

  double get _hours {
    final settings = ref.read(settingsProvider);
    if (_calcMode == CalcModes.fixed) {
      return WorkCalc.actualHours(
        durationMinutes: _durationMinutes,
        deductBreak: settings.deductBreak,
        breakMinutes: settings.breakMinutes,
      );
    }
    return WorkCalc.convertedHours(
      durationMinutes: _durationMinutes,
      rate: _rate,
      deductBreak: settings.deductBreak,
      breakMinutes: settings.breakMinutes,
      roundToMinute: settings.roundToMinute,
    );
  }

  double get _amount {
    final settings = ref.read(settingsProvider);
    if (_calcMode == CalcModes.fixed) {
      return WorkCalc.money(_hours, _fixedWage);
    }
    return WorkCalc.money(_hours, settings.effectiveHourlyWage);
  }

  // ------------------------------------------------------------------ 交互

  /// 按日历自动带出类型与倍率
  void _applyCalendarDefaults(DateTime date) {
    final settings = ref.read(settingsProvider);
    final type = CalendarRules.autoTypeFor(date);
    _type = type;
    _rate = settings.defaultRateOf(type);
    _rateController.text = _rateText(_rate);
    if (type != OvertimeTypes.custom) _calcMode = CalcModes.rate;
    _autoFromCalendar = true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    final date = dateOnly(picked);
    setState(() {
      _date = date;
      _applyCalendarDefaults(date);
    });
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
        if (!_byRange) _syncEndFromDuration();
      } else {
        _end = value;
      }
    });
  }

  void _syncEndFromDuration() {
    final start = parseTimeToMinutes(_start) ?? 0;
    _end = minutesToTime(start + _fixedDuration);
  }

  void _setByRange(bool value) {
    if (value == _byRange) return;
    final current = _durationMinutes;
    setState(() {
      _byRange = value;
      if (!value) {
        _fixedDuration = current.clamp(1, 1439);
        _syncEndFromDuration();
      }
    });
  }

  void _selectType(String type) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _type = type;
      _rate = settings.defaultRateOf(type);
      _rateController.text = _rateText(_rate);
      if (type != OvertimeTypes.custom) _calcMode = CalcModes.rate;
      _autoFromCalendar = CalendarRules.autoTypeFor(_date) == type;
    });
  }

  /// 选择固定加班时长（支持 3 小时、8 小时等快捷值）
  Future<void> _pickDuration() async {
    final hoursController = TextEditingController(text: '${_fixedDuration ~/ 60}');
    final minutesController = TextEditingController(text: '${_fixedDuration % 60}');
    String? error;

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void apply(int total) {
            hoursController.text = '${total ~/ 60}';
            minutesController.text = '${total % 60}';
            setDialogState(() => error = null);
          }

          void submit() {
            final hours = int.tryParse(hoursController.text.trim()) ?? -1;
            final minutes = int.tryParse(minutesController.text.trim()) ?? -1;
            if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
              setDialogState(() => error = '请输入 0-23 小时、0-59 分钟');
              return;
            }
            final total = hours * 60 + minutes;
            if (total <= 0) {
              setDialogState(() => error = '加班时长必须大于 0');
              return;
            }
            if (total >= 1440) {
              setDialogState(() => error = '单次时长最多 23 小时 59 分');
              return;
            }
            Navigator.of(dialogContext).pop(total);
          }

          return AlertDialog(
            title: const Text('选择加班时长'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in const <(int, String)>[
                        (30, '30分钟'),
                        (60, '1小时'),
                        (90, '1.5小时'),
                        (120, '2小时'),
                        (180, '3小时'),
                        (240, '4小时'),
                        (360, '6小时'),
                        (480, '8小时'),
                      ])
                        ActionChip(
                          label: Text(
                            item.$2,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => apply(item.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '小时',
                            isDense: true,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('时'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '分钟',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
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
              TextButton(
                onPressed: submit,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      hoursController.dispose();
      minutesController.dispose();
    });

    if (picked == null) return;
    setState(() {
      _fixedDuration = picked;
      _syncEndFromDuration();
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
    if (!_byRange && (_fixedDuration <= 0 || _fixedDuration >= 1440)) {
      _showMessage('请选择有效的加班时长');
      return;
    }
    if (_calcMode == CalcModes.fixed && _fixedWage <= 0) {
      _showMessage('请输入大于 0 的固定加班时薪');
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
      calcMode: _calcMode,
      fixedWage: _calcMode == CalcModes.fixed ? _fixedWage : 0,
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

  // ------------------------------------------------------------------- 视图

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
            _sectionTitle(theme, '加班时间'),
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('起止时间'),
                          icon: Icon(Icons.timelapse_outlined),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('固定时长'),
                          icon: Icon(Icons.hourglass_bottom_outlined),
                        ),
                      ],
                      selected: {_byRange},
                      onSelectionChanged: (values) =>
                          _setByRange(values.first),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
                if (_byRange)
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
                  )
                else ...[
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
                          leading: const Icon(Icons.hourglass_bottom_outlined),
                          title: const Text('加班时长'),
                          subtitle: Text(formatDuration(_fixedDuration)),
                          onTap: _pickDuration,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.stop_outlined),
                    enabled: false,
                    title: const Text('结束时间（自动计算）'),
                    subtitle: Text(
                      '$_end${_crossDay ? '（次日）' : ''}',
                      style: const TextStyle(color: Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _durationBox(theme, scheme, settings),
            const SizedBox(height: 16),

            _sectionTitle(theme, '加班类型'),
            Row(
              children: [
                for (var i = 0; i < OvertimeTypes.all.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _typeChip(scheme, OvertimeTypes.all[i])),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_type != OvertimeTypes.custom)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: OvertimeTypes.colorOf(_type).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.percent, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '倍率 ×${_rateText(_rate)}　$_type默认',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '倍率在设置中修改',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OvertimeTypes.colorOf(OvertimeTypes.custom)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: CalcModes.rate,
                            label: Text('按倍率'),
                          ),
                          ButtonSegment(
                            value: CalcModes.fixed,
                            label: Text('按固定时薪'),
                          ),
                        ],
                        selected: {_calcMode},
                        onSelectionChanged: (values) => setState(
                          () => _calcMode = values.first,
                        ),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_calcMode == CalcModes.rate)
                      TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: '倍率',
                          hintText: '例如 1.5',
                          isDense: true,
                          prefixIcon: Icon(Icons.percent),
                        ),
                        validator: (value) {
                          if (_calcMode != CalcModes.rate) return null;
                          final parsed =
                              double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return '请输入大于 0 的倍率';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final parsed = double.tryParse(value.trim());
                          if (parsed != null && parsed > 0) {
                            setState(() => _rate = parsed);
                          }
                        },
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _fixedWageController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: const InputDecoration(
                              labelText: '固定加班时薪',
                              hintText: '例如 60',
                              isDense: true,
                              prefixIcon: Icon(Icons.attach_money_outlined),
                            ),
                            validator: (value) {
                              if (_calcMode != CalcModes.fixed) return null;
                              final parsed =
                                  double.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return '请输入大于 0 的固定时薪';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final parsed = double.tryParse(value.trim());
                              if (parsed != null && parsed > 0) {
                                setState(() => _fixedWage = parsed);
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '金额 = 有效时长 × 固定加班时薪，不再乘倍率',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            if (_autoFromCalendar && _type != OvertimeTypes.custom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '已按日历自动选定：${CalendarRules.describe(_date)}，倍率 ×${_rateText(_rate)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            _sectionTitle(theme, '项目与备注'),
            TextFormField(
              controller: _projectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '项目',
                hintText: '例如：XX 服务器迁移',
                alignLabelWithHint: true,
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
            _card(
              scheme,
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

  Widget _typeChip(ColorScheme scheme, String type) {
    final selected = _type == type;
    final color = OvertimeTypes.colorOf(type);
    return ChoiceChip(
      label: Text(
        type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSecondaryContainer : color,
        ),
      ),
      selected: selected,
      selectedColor: color.withOpacity(0.18),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _selectType(type),
    );
  }

  /// 时长 / 折算 / 金额 预览（含休息时间扣除说明）
  Widget _durationBox(
    ThemeData theme,
    ColorScheme scheme,
    AppSettings settings,
  ) {
    final effective = _effectiveMinutes;
    final showDeduct = settings.deductBreak &&
        settings.breakMinutes > 0 &&
        effective != _durationMinutes;

    return Container(
      width: double.infinity,
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
          if (showDeduct) ...[
            const SizedBox(height: 4),
            Text(
              '扣除休息 ${settings.breakMinutes} 分钟 → 有效 ${formatDuration(effective)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _timeInvalid
                ? '结束时间不能等于开始时间，请重新选择'
                : _calcMode == CalcModes.fixed
                    ? '有效时长 ${formatHours(_hours)} 小时 × ¥${formatMoney(_fixedWage)}/小时'
                        '　预计金额 ¥${formatMoney(_amount)}'
                    : '折算 ${formatHours(_hours)} 小时　预计金额 ¥${formatMoney(_amount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _timeInvalid
                  ? scheme.error
                  : (_calcMode == CalcModes.fixed
                      ? scheme.tertiary
                      : scheme.onSurfaceVariant),
            ),
          ),
          if (settings.effectiveHourlyWage > 0 &&
              _calcMode != CalcModes.fixed) ...[
            const SizedBox(height: 2),
            Text(
              settings.useMonthlySalary
                  ? '月薪 ¥${formatMoney(settings.monthlySalary)} ÷ 21.75 ÷ 8 '
                      '= ¥${formatMoney(settings.effectiveHourlyWage)}/小时'
                  : '按当前时薪 ¥${formatMoney(settings.effectiveHourlyWage)}/小时计算',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ],
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

String _rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
