import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/holiday_file_service.dart';
import '../../data/holiday_store.dart';
import '../../providers/settings_provider.dart';
import 'settings_common.dart';

/// 二级设置：节假日数据（联网更新 / 文件导入 / 导出 / 恢复内置）
///
/// 节假日数据决定「法定节假日 3 倍 / 调休补班 / 连休日期」，
/// 内置数据随 APK 发布；后续年份缺失时可在此联网更新或导入文件。
class HolidaysSettingsPage extends ConsumerStatefulWidget {
  const HolidaysSettingsPage({super.key});

  @override
  ConsumerState<HolidaysSettingsPage> createState() =>
      _HolidaysSettingsPageState();
}

class _HolidaysSettingsPageState extends ConsumerState<HolidaysSettingsPage> {
  bool _busy = false;

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 解析结果确认后按年份覆盖写入
  Future<void> _confirmAndApply(
    HolidayParseResult result, {
    required String source,
  }) async {
    if (!mounted) return;
    final years = result.data.years.toList()..sort();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(source == HolidaySources.download ? '联网更新' : '导入文件'),
        content: Text(
          '将更新 ${years.join('、')} 年的节假日数据，'
          '其他年份保持不变。\n'
          '来源：${result.name.isEmpty ? '本地文件' : result.name}'
          '${result.ignored > 0 ? '（已忽略 ${result.ignored} 条非法数据）' : ''}\n'
          '确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final merged = HolidayStore.data.withReplacedYears(result.data);
    await HolidayStore.apply(
      merged,
      source: source,
      note: result.name,
    );
    if (mounted) setState(() {});
    _toast('节假日数据已更新，当前覆盖：${HolidayStore.yearsText} 年');
  }

  /// 联网下载最新节假日数据
  Future<void> _download() => _run(() async {
        final url = ref.read(settingsProvider).holidayUpdateUrl;
        _toast('正在下载节假日数据…');
        final result = await HolidayFileService.download(url);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await _confirmAndApply(result, source: HolidaySources.download);
      });

  /// 从本地文件导入（JSON / CSV）
  Future<void> _importFromFile() => _run(() async {
        final result = await HolidayFileService.pickAndParse();
        if (result == null) {
          _toast('已取消导入');
          return;
        }
        await _confirmAndApply(result, source: HolidaySources.import);
      });

  /// 导出当前数据为 JSON 并分享
  Future<void> _export() => _run(() async {
        await HolidayFileService.exportAndShare(HolidayStore.data);
        _toast('已生成节假日 JSON 文件');
      });

  /// 恢复为随应用发布的内置数据
  Future<void> _resetToBuiltin() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复内置数据'),
        content: Text(
          '将丢弃当前的「${HolidaySources.labelOf(HolidayStore.source)}」数据，'
          '恢复为随应用发布的内置节假日（${HolidayStore.yearsText} 年）。\n'
          '确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await HolidayStore.resetToBuiltin();
    if (mounted) setState(() {});
    _toast('已恢复内置节假日数据');
  }

  /// 编辑联网更新地址
  Future<void> _editUrl() async {
    final settings = ref.read(settingsProvider);
    final next = await promptText(
      context,
      title: '节假日更新地址',
      label: 'JSON 数据地址（https）',
      initialValue: settings.holidayUpdateUrl,
    );
    if (next == null || !mounted) return;
    ref.read(settingsProvider.notifier).setHolidayUpdateUrl(next);
    setState(() {});
    _toast('更新地址已保存');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final busyText = _busy ? '处理中…' : '';
    final updatedAt = HolidayStore.updatedAt;
    final isBuiltin = HolidayStore.isBuiltin;

    return Scaffold(
      appBar: AppBar(title: const Text('节假日数据')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '当前数据'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(
                  '来源：${HolidaySources.labelOf(HolidayStore.source)}'
                  '${HolidayStore.note.isEmpty ? '' : '（${HolidayStore.note}）'}',
                ),
                subtitle: Text(
                  '覆盖年份：${HolidayStore.yearsText} 年 · '
                  '共 ${HolidayStore.data.length} 条日期',
                ),
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('最近更新'),
                subtitle: Text(
                  updatedAt == null
                      ? '尚未手动更新（使用内置数据）'
                      : DateFormat('yyyy-MM-dd HH:mm').format(updatedAt),
                ),
              ),
            ],
          ),
          settingsHeader(context, '更新方式'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('联网更新'),
                subtitle: Text(
                  busyText.isEmpty ? '从数据源下载最新节假日（需联网）' : busyText,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _download,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('从文件导入'),
                subtitle: Text(
                  busyText.isEmpty ? '选择本地 JSON / CSV 节假日文件' : busyText,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _importFromFile,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('导出当前数据'),
                subtitle: Text(
                  busyText.isEmpty ? '导出为 JSON，可用于备份与分享' : busyText,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _export,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: const Text('更新地址'),
                subtitle: Text(
                  settings.holidayUpdateUrl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _editUrl,
              ),
            ],
          ),
          settingsHeader(context, '说明'),
          settingsCard(
            context,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  '· 更新按年份覆盖：导入 2027 年数据不会影响已有的 2025 / 2026 年。\n'
                  '· JSON 需含 statutory（法定）、makeup（补班）、breaks（连休）字段；\n'
                  '  日期为 2027-01-01 或区间 2027-01-01..2027-01-03。\n'
                  '· CSV 需含 kind、date 两列，kind 取 statutory / makeup / break。\n'
                  '· 更新失败时可改用「从文件导入」，数据始终保存在本机。',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
          if (!isBuiltin) ...[
            settingsHeader(context, '恢复'),
            settingsCard(
              context,
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_outlined),
                  title: const Text('恢复内置数据'),
                  subtitle: const Text('丢弃更新结果，回到随应用发布的数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _resetToBuiltin,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
