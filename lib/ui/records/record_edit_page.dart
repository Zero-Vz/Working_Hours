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

  late DateTime _date;
  late String _start;
  late String _end;
  late String _type;
  late double _rate;
  late String _calcMode;
  late double _fixedWage;

  /// 本条记录的休息分钟数（kFollowSettingsBreak 表示跟随设置）
  late int _breakOverride;

  /// true：按开始 / 结束时间；false：按固定时长
  late bool _byRange;

  /// 固定时长模式下填写的实际加班时长（分钟，不含休息）
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
    _start = record?.startTime ?? _defaultStart(settings);
    _end = record?.endTime ?? _defaultEnd(settings, _start);
    _type = record?.type ?? OvertimeTypes.weekday;
    _rate = record?.rate ?? settings.defaultRateOf(_type);
    _calcMode = CalcModes.normalize(record?.calcMode);
    _fixedWage =
        (record?.fixedWage ?? 0) > 0 ? record!.fixedWage : settings.fixedWage;
    _byRange = true;
    _fixedDuration =
        record?.durationMinutes ?? calcDurationMinutes(_start, _end);
    if (record == null) {
      // 新增：带出上一次填写的固定时长
      final remembered = settings.lastFixedDuration;
      if (remembered > 0 && remembered < 1440) _fixedDuration = remembered;
    }
    if (_fixedDuration <= 0 || _fixedDuration >= 1440) _fixedDuration = 180;
    _breakOverride = record?.breakMinutes ?? kFollowSettingsBreak;
    if (record != null) {
      // 记录存的是起止跨度（含休息），固定时长模式显示净时长
      final effectiveBreak =
          settings.deductBreak ? WorkCalc.breakMinutesOf(record, settings) : 0;
      final net = record.durationMinutes - effectiveBreak;
      if (net > 0) _fixedDuration = net.clamp(1, 1439);
    }
    _compensatory = record?.isCompensatory ?? false;
    _settled = record?.isSettled ?? false;
    _projectController.text = record?.project ?? settings.defaultProject;
    _noteController.text = record?.note ?? '';

    if (record == null) {
      // 新增：按日历自动选择类型与倍率
      _applyCalendarDefaults(_date);
    }
  }

  @override
  void dispose() {
    _projectController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 新增记录默认开始时间（记住上一次填写的值）
  String _defaultStart(AppSettings settings) {
    final value = settings.lastStartTime;
    return parseTimeToMinutes(value) == null ? '18:00' : value;
  }

  /// 新增记录默认结束时间：与开始时间相同或非法时回退，避免一进来就报错
  String _defaultEnd(AppSettings settings, String start) {
    final value = settings.lastEndTime;
    if (parseTimeToMinutes(value) == null || value == start) {
      return minutesToTime((parseTimeToMinutes(start) ?? 0) + 180);
    }
    return value;
  }

  // ---------------------------------------------------------------- 计算预览

  AppSettings get _settings => ref.read(settingsProvider);

  /// 本条记录生效的休息分钟数
  int get _breakMinutes =>
      _breakOverride >= 0 ? _breakOverride : _settings.breakMinutes;

  /// 是否扣除休息
  bool get _deductBreak => _settings.deductBreak;

  /// 存库的原始时长 = 起止跨度（含休息）
  ///
  /// 起止时间模式：直接取差值；
  /// 固定时长模式：填写的是实际加班时长，跨度 = 时长 + 休息。
  int get _durationMinutes => _byRange
      ? calcDurationMinutes(_start, _end)
      : _fixedDuration + (_deductBreak ? _breakMinutes : 0);

  /// 扣除休息后的有效时长
  int get _netMinutes => WorkCalc.effectiveMinutes(
        _durationMinutes,
        deductBreak: _deductBreak,
        breakMinutes: _breakMinutes,
      );

  bool get _crossDay => isOvernightRange(_start, _end);

  /// 起止时间相等，或含休息后跨度达到 24 小时
  bool get _timeInvalid =>
      (_byRange && _start == _end) || (!_byRange && _durationMinutes >= 1440);

  int get _effectiveMinutes => _netMinutes;

  double get _hours {
    final settings = _settings;
    if (_calcMode == CalcModes.fixed) {
      return _netMinutes / 60.0;
    }
    return WorkCalc.convertedHours(
      durationMinutes: _durationMinutes,
      rate: _rate,
      deductBreak: _deductBreak,
      breakMinutes: _breakMinutes,
      roundToMinute: settings.roundToMinute,
    );
  }

  double get _amount {
    final settings = _settings;
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
    _end = minutesToTime(start + _durationMinutes);
  }

  void _setByRange(bool value) {
    if (value == _byRange) return;
    final current = _durationMinutes;
    setState(() {
      _byRange = value;
      if (!value) {
        // 切到固定时长：填写的是净时长（跨度 - 休息），结束时间保持不变
        final net = current - (_deductBreak ? _breakMinutes : 0);
        _fixedDuration = net < 1 ? 1 : (net > 1439 ? 1439 : net);
        _syncEndFromDuration();
      }
    });
  }

  void _selectType(String type) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _type = type;
      _rate = settings.defaultRateOf(type);
      if (type != OvertimeTypes.custom) _calcMode = CalcModes.rate;
      _autoFromCalendar = CalendarRules.autoTypeFor(_date) == type;
    });
  }

  /// 自定义类型的参数弹窗（倍率 / 固定时薪），与其余类型共用同一个信息框
  Future<void> _pickCustomParams() async {
    var mode = _calcMode;
    final rateController = TextEditingController(text: formatRate(_rate));
    final wageController = TextEditingController(text: formatMoney(_fixedWage));
    String? error;

    // 只把结果带回页面，由页面统一 setState（弹窗内不直接改页面状态）
    final params = await showDialog<(String, double)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            if (mode == CalcModes.rate) {
              final parsed = double.tryParse(rateController.text.trim());
              if (parsed == null || parsed <= 0) {
                setDialogState(() => error = '请输入大于 0 的倍率');
                return;
              }
              Navigator.of(dialogContext).pop((CalcModes.rate, parsed));
            } else {
              final parsed = double.tryParse(wageController.text.trim());
              if (parsed == null || parsed <= 0) {
                setDialogState(() => error = '请输入大于 0 的固定时薪');
                return;
              }
              Navigator.of(dialogContext).pop((CalcModes.fixed, parsed));
            }
          }

          return AlertDialog(
            title: const Text('自定义参数'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      selected: {mode},
                      onSelectionChanged: (values) => setDialogState(() {
                        mode = values.first;
                        error = null;
                      }),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (mode == CalcModes.rate)
                    TextField(
                      controller: rateController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: '倍率',
                        hintText: '例如 1.50',
                        errorText: error,
                        isDense: true,
                        prefixIcon: const Icon(Icons.percent),
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                      onSubmitted: (_) => submit(),
                    )
                  else
                    TextField(
                      controller: wageController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: '固定加班时薪',
                        hintText: '例如 60',
                        errorText: error,
                        isDense: true,
                        prefixIcon:
                            const Icon(Icons.attach_money_outlined),
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                      onSubmitted: (_) => submit(),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    mode == CalcModes.rate
                        ? '金额 = 有效时长 × 倍率 × 时薪'
                        : '金额 = 有效时长 × 固定加班时薪，不再乘倍率',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(onPressed: submit, child: const Text('确定')),
            ],
          );
        },
      ),
    );
    // 控制器随弹窗闭包回收：弹窗退出动画结束前销毁它会触发框架断言

    if (params == null || !mounted) return;
    setState(() {
      _calcMode = params.$1;
      if (params.$1 == CalcModes.rate) {
        _rate = params.$2;
      } else {
        _fixedWage = params.$2;
      }
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
            // 固定时长模式下跨度还要加上休息，避免越过 24 小时
            final limit = 1440 - (_deductBreak ? _breakMinutes : 0);
            if (total >= limit) {
              setDialogState(
                () => error = (_deductBreak && _breakMinutes > 0)
                    ? '加班时长 + 休息 $_breakMinutes 分最多 23 小时 59 分'
                    : '单次时长最多 23 小时 59 分',
              );
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
    );
    // 控制器随弹窗闭包回收：弹窗退出动画结束前销毁它会触发框架断言

    if (picked == null) return;
    setState(() {
      _fixedDuration = picked;
      _syncEndFromDuration();
    });
  }

  /// 选择本条记录的休息时长（默认跟随设置）
  Future<void> _pickBreakMinutes() async {
    final settings = _settings;
    final controller = TextEditingController(text: '$_breakMinutes');
    String? error;

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final value = int.tryParse(controller.text.trim());
            if (value == null || value < 0 || value > 1440) {
              setDialogState(() => error = '请输入 0-1440 分钟');
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: const Text('本条记录的休息时长'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.sync_outlined, size: 16),
                        label: Text(
                          '跟随设置（${settings.breakMinutes} 分）',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => Navigator.of(dialogContext)
                            .pop(kFollowSettingsBreak),
                      ),
                      for (final value in const [0, 15, 30, 45, 60, 90])
                        ActionChip(
                          label: Text(
                            '$value 分钟',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '自定义分钟',
                      errorText: error,
                      isDense: true,
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开启扣休息时，结束时间 = 开始 + 加班时长 + 休息；'
                    '起止时间模式下该休息时长用于扣除。',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
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
    );
    // 控制器随弹窗闭包回收：弹窗退出动画结束前销毁它会触发框架断言

    if (picked == null) return;
    setState(() {
      _breakOverride = picked;
      if (!_byRange) _syncEndFromDuration();
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
      _showMessage(
        !_byRange && _durationMinutes >= 1440
            ? '含休息后总时长超过 24 小时，请调整'
            : '结束时间不能等于开始时间',
      );
      return;
    }
    if (!_byRange && (_fixedDuration <= 0 || _fixedDuration >= 1440)) {
      _showMessage('请选择有效的加班时长');
      return;
    }
    if (_calcMode == CalcModes.rate && _rate <= 0) {
      _showMessage('请输入大于 0 的倍率');
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
      breakMinutes: _breakOverride,
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
    // 记住本次的起止时间与固定时长，下次新增直接带出
    ref.read(settingsProvider.notifier).rememberEntry(
          start: _start,
          end: _end,
          fixedDuration: _fixedDuration,
        );
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
                else
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
                          leading:
                              const Icon(Icons.hourglass_bottom_outlined),
                          title: const Text('加班时长'),
                          subtitle: Text(
                            '${formatDuration(_fixedDuration)}'
                            '${_deductBreak ? '（净）' : ''}',
                          ),
                          onTap: _pickDuration,
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _breakTile(theme, settings),
                if (!_byRange) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.stop_outlined),
                    enabled: false,
                    title: const Text('结束时间（自动计算）'),
                    subtitle: Text(
                      '$_end${_crossDay ? '（次日）' : ''}'
                      '${_deductBreak ? '　含休息 $_breakMinutes 分' : ''}',
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
            _rateBox(theme, scheme),
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
                      '已按日历自动选定：${CalendarRules.describe(_date)}，倍率 ×${formatRate(_rate)}',
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

  /// 休息时长（可单独设置，默认与设置一致）
  Widget _breakTile(ThemeData theme, AppSettings settings) {
    final scheme = theme.colorScheme;
    final custom = _breakOverride >= 0;

    return ListTile(
      leading: const Icon(Icons.coffee_outlined),
      title: const Text('休息时长'),
      subtitle: Text(
        !settings.deductBreak
            ? '已关闭扣休息，暂不参与计算'
            : custom
                ? '仅本条记录生效（设置默认 ${settings.breakMinutes} 分钟）'
                : '跟随设置（${settings.breakMinutes} 分钟），点击可单独修改',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_breakMinutes 分钟',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.edit_outlined, size: 17, color: scheme.outline),
        ],
      ),
      onTap: _pickBreakMinutes,
    );
  }

  Widget _typeChip(ColorScheme scheme, String type) {    final selected = _type == type;
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

  /// 加班类型下方的信息框：四个类型外观完全一致，
  /// 自定义类型点击后弹窗修改倍率 / 固定时薪
  Widget _rateBox(ThemeData theme, ColorScheme scheme) {
    final custom = _type == OvertimeTypes.custom;
    final color = OvertimeTypes.colorOf(_type);
    final detail = custom && _calcMode == CalcModes.fixed
        ? '固定时薪 ¥${formatMoney(_fixedWage)}/小时'
        : '倍率 ×${formatRate(_rate)}';
    final text = theme.textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: custom ? _pickCustomParams : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.percent, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$detail　$_type${custom ? '' : '默认'}',
                  style: text.bodySmall,
                ),
              ),
              if (custom)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '点击修改',
                      style: text.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.edit_outlined, size: 16, color: scheme.primary),
                  ],
                )
              else
                Text(
                  '倍率在设置中修改',
                  style: text.labelSmall?.copyWith(color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 时长 / 折算 / 金额 预览（含休息时间扣除说明）
  Widget _durationBox(
    ThemeData theme,
    ColorScheme scheme,
    AppSettings settings,
  ) {
    final effective = _effectiveMinutes;
    final showDeduct = _deductBreak &&
        _breakMinutes > 0 &&
        effective != _durationMinutes;
    final spanInvalid = !_byRange && _durationMinutes >= 1440;
    final invalid = _timeInvalid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: invalid
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
              if (showDeduct && !_byRange) ...[
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
                    '含休息 $_breakMinutes 分',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
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
              _byRange
                  ? '扣除休息 $_breakMinutes 分钟 → 有效 ${formatDuration(effective)}'
                  : '休息 $_breakMinutes 分钟计入跨度 → 有效 ${formatDuration(effective)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!_byRange && _deductBreak && !spanInvalid) ...[
            const SizedBox(height: 2),
            Text(
              '$_start + ${formatDuration(_fixedDuration)} + 休息 $_breakMinutes 分 '
              '→ $_end',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            invalid
                ? (spanInvalid
                    ? '含休息后总时长超过 24 小时，请调整时长或休息时长'
                    : '结束时间不能等于开始时间，请重新选择')
                : _calcMode == CalcModes.fixed
                    ? '有效时长 ${formatHours(_hours)} 小时 × ¥${formatMoney(_fixedWage)}/小时'
                        '　预计金额 ¥${formatMoney(_amount)}'
                    : '折算 ${formatHours(_hours)} 小时　预计金额 ¥${formatMoney(_amount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: invalid
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
