import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/overtime_record.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/calculations.dart';

/// 新增/编辑加班记录页
class RecordFormScreen extends ConsumerStatefulWidget {
  final OvertimeRecord? record;

  const RecordFormScreen({super.key, this.record});

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectController = TextEditingController();
  final _noteController = TextEditingController();
  final _rateController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late OvertimeType _selectedType;
  late double _rate;
  late bool _isCompensatory;
  late bool _isSettled;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _selectedDate = record?.date ?? DateTime.now();
    _startTime = record?.startTime ?? const TimeOfDay(hour: 18, minute: 0);
    _endTime = record?.endTime ?? const TimeOfDay(hour: 21, minute: 0);
    _selectedType = record?.type ?? OvertimeType.workday;
    _rate = record?.rate ?? _selectedType.defaultRate;
    _isCompensatory = record?.isCompensatory ?? false;
    _isSettled = record?.isSettled ?? false;
    _projectController.text = record?.project ?? '';
    _noteController.text = record?.note ?? '';
    _rateController.text = _rate.toString();
  }

  @override
  void dispose() {
    _projectController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  int get _durationMinutes => Calculations.calculateDurationMinutes(_startTime, _endTime);

  double get _convertedHours => Calculations.calculateConvertedHours(_durationMinutes, _rate);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hourlyWage = double.tryParse(settings['hourly_wage'] ?? '50.0') ?? 50.0;
    final amount = Calculations.calculateAmount(_durationMinutes, _rate, hourlyWage);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '新增记录'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 日期选择
            _buildSectionTitle('日期'),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // 时间选择
            _buildSectionTitle('时间'),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('开始时间'),
                    subtitle: Text(Calculations.formatTimeOfDay(_startTime)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.stop),
                    title: const Text('结束时间'),
                    subtitle: Text(Calculations.formatTimeOfDay(_endTime)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 时长显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timelapse, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '加班时长: ${Calculations.formatDuration(_durationMinutes)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 加班类型
            _buildSectionTitle('加班类型'),
            SegmentedButton<OvertimeType>(
              segments: OvertimeType.values.map((type) {
                return ButtonSegment(
                  value: type,
                  label: Text(type.label),
                  icon: Text('${type.defaultRate}x', style: const TextStyle(fontSize: 10)),
                );
              }).toList(),
              selected: {_selectedType},
              onSelectionChanged: (types) {
                setState(() {
                  _selectedType = types.first;
                  _rate = _selectedType.defaultRate;
                  _rateController.text = _rate.toString();
                });
              },
            ),
            const SizedBox(height: 16),

            // 倍率
            _buildSectionTitle('倍率'),
            TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '加班倍率',
                hintText: '如 1.5、2.0、3.0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.percent),
                suffixText: 'x',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入倍率';
                final v = double.tryParse(value);
                if (v == null || v <= 0) return '倍率必须大于0';
                return null;
              },
              onChanged: (value) {
                final v = double.tryParse(value);
                if (v != null && v > 0) {
                  setState(() => _rate = v);
                }
              },
            ),
            const SizedBox(height: 16),

            // 项目
            _buildSectionTitle('项目'),
            TextFormField(
              controller: _projectController,
              decoration: InputDecoration(
                labelText: '项目名称',
                hintText: '可选',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.folder),
              ),
            ),
            const SizedBox(height: 16),

            // 备注
            _buildSectionTitle('备注'),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '备注',
                hintText: '可选',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 16),

            // 调休和结算
            _buildSectionTitle('其他'),
            SwitchListTile(
              title: const Text('是否调休'),
              subtitle: const Text('标记此加班是否用于调休'),
              value: _isCompensatory,
              onChanged: (v) => setState(() => _isCompensatory = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            SwitchListTile(
              title: const Text('是否已结算'),
              subtitle: const Text('标记此加班费是否已发放'),
              value: _isSettled,
              onChanged: (v) => setState(() => _isSettled = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 24),

            // 计算结果预览
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text('计算预览', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  _buildPreviewRow('实际时长', Calculations.formatDuration(_durationMinutes)),
                  _buildPreviewRow('倍率', '${_rate}x'),
                  _buildPreviewRow('折算工时', Calculations.formatHours(_convertedHours)),
                  _buildPreviewRow('时薪', Calculations.formatAmount(hourlyWage)),
                  const Divider(),
                  _buildPreviewRow(
                    '预计加班费',
                    Calculations.formatAmount(amount),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: isBold
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('zh', 'CN'),
          child: child,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // 校验：结束时间不能等于开始时间
    if (_startTime.hour == _endTime.hour && _startTime.minute == _endTime.minute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束时间不能等于开始时间')),
      );
      return;
    }

    final settings = ref.read(settingsProvider);
    final hourlyWage = double.tryParse(settings['hourly_wage'] ?? '50.0') ?? 50.0;
    final duration = _durationMinutes;
    final amount = Calculations.calculateAmount(duration, _rate, hourlyWage);

    final record = OvertimeRecord(
      id: widget.record?.id,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      durationMinutes: duration,
      type: _selectedType,
      rate: _rate,
      project: _projectController.text.trim(),
      note: _noteController.text.trim(),
      isCompensatory: _isCompensatory,
      isSettled: _isSettled,
      amount: amount,
    );

    if (_isEditing) {
      ref.read(recordsProvider.notifier).updateRecord(record);
    } else {
      ref.read(recordsProvider.notifier).addRecord(record);
    }

    Navigator.pop(context, true);
  }
}