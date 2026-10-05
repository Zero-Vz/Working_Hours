import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/csv/leave_csv_service.dart';
import '../../data/csv/record_csv_service.dart';
import '../../providers/income_items_provider.dart';
import '../../providers/leaves_provider.dart';
import '../../providers/records_provider.dart';
import 'settings_common.dart';

/// 二级设置：数据管理（导入 / 导出 / 清空）
class DataSettingsPage extends ConsumerStatefulWidget {
  const DataSettingsPage({super.key});

  @override
  ConsumerState<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends ConsumerState<DataSettingsPage> {
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

  Future<void> _exportRecords() => _run(() async {
        final records = ref.read(recordsProvider);
        if (records.isEmpty) {
          _toast('暂无加班记录可导出');
          return;
        }
        await RecordCsvService.exportAndShare(records);
        _toast('已生成 CSV，共 ${records.length} 条加班记录');
      });

  Future<void> _importRecords() => _run(() async {
        final records = await RecordCsvService.pickAndParse();
        if (records == null) {
          _toast('已取消导入');
          return;
        }
        final added =
            await ref.read(recordsProvider.notifier).importRecords(records);
        _toast('导入完成：新增 $added 条，跳过 ${records.length - added} 条重复');
      });

  Future<void> _exportLeaves() => _run(() async {
        final leaves = ref.read(leavesProvider);
        if (leaves.isEmpty) {
          _toast('暂无请假记录可导出');
          return;
        }
        await LeaveCsvService.exportAndShare(leaves);
        _toast('已生成 CSV，共 ${leaves.length} 条请假记录');
      });

  Future<void> _importLeaves() => _run(() async {
        final leaves = await LeaveCsvService.pickAndParse();
        if (leaves == null) {
          _toast('已取消导入');
          return;
        }
        final added =
            await ref.read(leavesProvider.notifier).importLeaves(leaves);
        _toast('导入完成：新增 $added 条，跳过 ${leaves.length - added} 条重复');
      });

  Future<void> _clearAll() async {
    if (_busy) return;
    final records = ref.read(recordsProvider).length;
    final leaves = ref.read(leavesProvider).length;
    final items = ref.read(incomeItemsProvider).length;
    if (records + leaves + items == 0) {
      _toast('当前没有数据');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空所有数据'),
        content: Text(
          '将删除 $records 条加班记录、$leaves 条请假记录与 '
          '$items 个工资项，且无法恢复。确定继续吗？',
        ),
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
    await ref.read(leavesProvider.notifier).clear();
    await ref.read(incomeItemsProvider.notifier).clear();
    _toast('已清空全部数据');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busyText = _busy ? '处理中…' : '';

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          settingsHeader(context, '加班记录 CSV'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('导出加班记录'),
                subtitle: Text(busyText.isEmpty ? '导出全部记录，可通过系统分享保存' : busyText),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _exportRecords,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('导入加班记录'),
                subtitle: Text(busyText.isEmpty ? '自动跳过重复记录' : busyText),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _importRecords,
              ),
            ],
          ),
          settingsHeader(context, '请假记录 CSV'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('导出请假记录'),
                subtitle: Text(busyText.isEmpty ? '含带薪 / 无薪、天数与扣款' : busyText),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _exportLeaves,
              ),
              settingsDivider,
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('导入请假记录'),
                subtitle: Text(busyText.isEmpty ? '自动跳过重复记录' : busyText),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _importLeaves,
              ),
            ],
          ),
          settingsHeader(context, '危险操作'),
          settingsCard(
            context,
            children: [
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(
                  '清空所有数据',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text('加班记录、请假记录与工资项一并删除'),
                onTap: _busy ? null : _clearAll,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
