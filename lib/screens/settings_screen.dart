import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/records_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/csv_utils.dart';

/// 设置页
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _wageController = TextEditingController();
  final _workdayRateController = TextEditingController();
  final _restdayRateController = TextEditingController();
  final _holidayRateController = TextEditingController();
  final _breakMinutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 延迟加载设置值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  void _loadSettings() {
    final settings = ref.read(settingsProvider);
    _wageController.text = settings['hourly_wage'] ?? '50.0';
    _workdayRateController.text = settings['workday_rate'] ?? '1.5';
    _restdayRateController.text = settings['restday_rate'] ?? '2.0';
    _holidayRateController.text = settings['holiday_rate'] ?? '3.0';
    _breakMinutesController.text = settings['break_minutes'] ?? '0';
  }

  @override
  void dispose() {
    _wageController.dispose();
    _workdayRateController.dispose();
    _restdayRateController.dispose();
    _holidayRateController.dispose();
    _breakMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final deductBreak = settings['deduct_break'] == '1';
    final roundToMinute = settings['round_to_minute'] == '1';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 时薪设置
          _buildSectionTitle('薪资设置'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _wageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '时薪（元/小时）',
                      prefixIcon: const Icon(Icons.payments),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixText: '元',
                    ),
                    onFieldSubmitted: (value) => _saveSetting('hourly_wage', value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 默认倍率设置
          _buildSectionTitle('默认倍率'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.work, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('工作日倍率')),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _workdayRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixText: 'x',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onFieldSubmitted: (value) => _saveSetting('workday_rate', value),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.weekend, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('休息日倍率')),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _restdayRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixText: 'x',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onFieldSubmitted: (value) => _saveSetting('restday_rate', value),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.celebration, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('节假日倍率')),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _holidayRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixText: 'x',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onFieldSubmitted: (value) => _saveSetting('holiday_rate', value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 其他设置
          _buildSectionTitle('计算设置'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('扣除休息时间'),
                  subtitle: const Text('从加班时长中扣除休息时间'),
                  value: deductBreak,
                  onChanged: (v) {
                    _saveSetting('deduct_break', v ? '1' : '0');
                  },
                ),
                if (deductBreak)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      controller: _breakMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '休息时间（分钟）',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixText: '分钟',
                      ),
                      onFieldSubmitted: (value) => _saveSetting('break_minutes', value),
                    ),
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('四舍五入到分钟'),
                  subtitle: const Text('时长精确到分钟'),
                  value: roundToMinute,
                  onChanged: (v) {
                    _saveSetting('round_to_minute', v ? '1' : '0');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 数据管理
          _buildSectionTitle('数据管理'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('导出 CSV'),
                  subtitle: const Text('将所有记录导出为CSV文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportCsv,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('导入 CSV'),
                  subtitle: const Text('从CSV文件导入记录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importCsv,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                  title: Text('清空所有数据', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  subtitle: const Text('删除所有加班记录，不可恢复'),
                  onTap: _confirmClearAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
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

  void _saveSetting(String key, String value) {
    ref.read(settingsProvider.notifier).setSetting(key, value);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final recordsAsync = ref.read(recordsProvider);
      final records = recordsAsync.valueOrNull ?? [];
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可导出的记录')),
          );
        }
        return;
      }

      final csvContent = CsvUtils.exportToCsv(records);
      final filePath = await CsvUtils.saveCsvToFile(csvContent);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: '加班记录导出',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importCsv() async {
    // 由于 file_picker 不在依赖中，使用文本输入方式导入
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 CSV'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: '粘贴CSV内容...\n格式: 日期,开始时间,结束时间,时长(分钟),加班类型,倍率,项目,备注,是否调休,是否已结算,折算工时,预计金额',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final records = await CsvUtils.importFromCsv(result);
        if (records.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未解析到有效记录')),
            );
          }
          return;
        }
        ref.read(recordsProvider.notifier).importRecords(records);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 ${records.length} 条记录')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: $e')),
          );
        }
      }
    }
    controller.dispose();
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('此操作将删除所有加班记录，且不可恢复。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(recordsProvider.notifier).deleteAllRecords();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('所有数据已清空')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }
}