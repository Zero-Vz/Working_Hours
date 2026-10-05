import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../data/csv/record_csv_service.dart';
import '../../providers/records_provider.dart';
import '../../providers/settings_provider.dart';

/// 设置页：时薪 / 默认倍率 / 计算规则 / 主题 / 导入导出
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  void _toast(String text) {
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<double?> _promptNumber({
    required String title,
    required String label,
    required String initialValue,
    bool decimal = true,
    double min = 0,
    double? max,
    String errorText = '请输入有效数字',
  }) {
    final controller = TextEditingController(text: initialValue);
    String? error;

    return showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed < min || (max != null && parsed > max)) {
                setDialogState(() => error = errorText);
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            }

            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: decimal,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: label,
                  errorText: error,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: submit,
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _exportCsv() async {
    if (_busy) return;
    final records = ref.read(recordsProvider);
    if (records.isEmpty) {
      _toast('暂无记录可导出');
      return;
    }
    setState(() => _busy = true);
    try {
      await RecordCsvService.exportAndShare(records);
      _toast('已生成 CSV，共 ${records.length} 条记录');
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final records = await RecordCsvService.pickAndParse();
      if (records == null) {
        _toast('已取消导入');
        return;
      }
      final added =
          await ref.read(recordsProvider.notifier).importRecords(records);
      _toast('导入完成：新增 $added 条，跳过 ${records.length - added} 条重复');
    } on FormatException catch (e) {
      _toast('导入失败：${e.message}');
    } catch (e) {
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll() async {
    final count = ref.read(recordsProvider).length;
    if (count == 0) {
      _toast('当前没有数据');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空所有数据'),
        content: Text('将删除全部 $count 条加班记录，且无法恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '清空',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recordsProvider.notifier).clear();
    _toast('已清空全部记录');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _header(theme, '计算设置'),
          _card(
            children: [
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
                  final value = await _promptNumber(
                    title: '设置时薪',
                    label: '元 / 小时',
                    initialValue: formatMoney(settings.hourlyWage),
                    min: 0,
                    max: 1000000,
                  );
                  if (value != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setHourlyWage(value);
                    _toast('时薪已更新，金额已重算');
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              for (final type in OvertimeTypes.all)
                ListTile(
                  leading: Icon(OvertimeTypes.iconOf(type)),
                  title: Text('默认倍率 · $type'),
                  trailing: Text(
                    '×${_rateText(settings.defaultRateOf(type))}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    final value = await _promptNumber(
                      title: '默认倍率 · $type',
                      label: '倍率',
                      initialValue:
                          _rateText(settings.defaultRateOf(type)),
                      min: 0.01,
                      max: 100,
                    );
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setRateFor(type, value);
                      _toast('已更新 $type 默认倍率');
                    }
                  },
                ),
            ],
          ),
          _card(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.coffee_outlined),
                title: const Text('扣除休息时间'),
                subtitle: Text(
                  settings.deductBreak
                      ? '每条记录扣除 ${settings.breakMinutes} 分钟'
                      : '按完整时长计算',
                ),
                value: settings.deductBreak,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setDeductBreak(value);
                  _toast(value ? '已开启休息时间扣除' : '已关闭休息时间扣除');
                },
              ),
              if (settings.deductBreak)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('休息时长'),
                  trailing: Text('${settings.breakMinutes} 分钟'),
                  onTap: () async {
                    final value = await _promptNumber(
                      title: '休息时长',
                      label: '分钟',
                      initialValue: '${settings.breakMinutes}',
                      decimal: false,
                      min: 0,
                      max: 1440,
                    );
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setBreakMinutes(value.round());
                    }
                  },
                ),
              SwitchListTile(
                secondary: const Icon(Icons.adjust_outlined),
                title: const Text('四舍五入到分钟'),
                subtitle: const Text('折算工时先按分钟取整再计算金额'),
                value: settings.roundToMinute,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).setRoundToMinute(value),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('默认项目'),
                trailing: Text(
                  settings.defaultProject.isEmpty
                      ? '未设置'
                      : settings.defaultProject,
                ),
                onTap: () async {
                  final value = await _promptText(
                    title: '默认项目',
                    label: '项目名称',
                    initialValue: settings.defaultProject,
                  );
                  if (value != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setDefaultProject(value.trim());
                  }
                },
              ),
            ],
          ),

          _header(theme, '外观'),
          _card(
            children: [
              for (final item in const <(String, String)>[
                ('system', '跟随系统'),
                ('light', '浅色模式'),
                ('dark', '深色模式'),
              ])
                RadioListTile<String>(
                  title: Text(item.$2),
                  value: item.$1,
                  groupValue: settings.themeMode,
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(settingsProvider.notifier).setThemeMode(value);
                  },
                ),
            ],
          ),

          _header(theme, '数据管理'),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('导出 CSV'),
                subtitle: Text(
                  _busy ? '处理中…' : '导出全部记录，可通过系统分享保存',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _exportCsv,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('导入 CSV'),
                subtitle: Text(
                  _busy ? '处理中…' : '自动跳过重复记录',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _importCsv,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(
                  '清空所有数据',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: _busy ? null : _clearAll,
              ),
            ],
          ),

          _header(theme, '关于'),
          _card(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('记工时 v$kAppVersion'),
                subtitle: Text(
                  '纯离线应用：不联网、不登录、不申请任何权限；'
                  '所有数据仅保存在本机。',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
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
}

String _rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
