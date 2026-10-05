import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/calc.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/overtime_record.dart';
import '../../providers/filter_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';
import 'record_edit_page.dart';

/// 记录列表页：按月筛选、按项目搜索、左滑删除、点击编辑
class RecordListPage extends ConsumerStatefulWidget {
  const RecordListPage({super.key});

  @override
  ConsumerState<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends ConsumerState<RecordListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth(DateTime month) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(picked.year, picked.month);
  }

  Future<void> _openEdit(OvertimeRecord? record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordEditPage(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final month = ref.watch(selectedMonthProvider);
    final query = ref.watch(searchQueryProvider);
    final records = ref.watch(filteredRecordsProvider);
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(monthlyStatsProvider(YearMonth.of(month)));
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记工时'),
        actions: [
          IconButton(
            tooltip: '选择月份',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _pickMonth(month),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(month, query),
          _buildSummary(scheme, stats),
          Expanded(
            child: records.isEmpty
                ? _buildEmpty(scheme, query.trim().isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 96),
                    itemCount: records.length,
                    itemBuilder: (context, index) => _buildItem(
                      context,
                      messenger,
                      settings,
                      records[index],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(null),
        icon: const Icon(Icons.add),
        label: const Text('新增记录'),
      ),
    );
  }

  Widget _buildFilterBar(DateTime month, String query) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上一月',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => ref
                    .read(selectedMonthProvider.notifier)
                    .state = DateTime(month.year, month.month - 1),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _pickMonth(month),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatMonthCn(month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '下一月',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => ref
                    .read(selectedMonthProvider.notifier)
                    .state = DateTime(month.year, month.month + 1),
              ),
            ],
          ),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: '搜索项目 / 备注 / 类型',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummary(ColorScheme scheme, MonthlyStats stats) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '共 ${stats.count} 条',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          Text(
            '时长 ${formatDuration(stats.rawMinutes)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          Text(
            '折算 ${formatHours(stats.hours)} 小时',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          Text(
            '预计 ¥${formatMoney(stats.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme, bool searching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searching ? Icons.search_off_outlined : Icons.event_note_outlined,
            size: 56,
            color: scheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            searching ? '没有匹配的记录' : '本月还没有加班记录',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          if (!searching) ...[
            const SizedBox(height: 6),
            Text(
              '点击右下角「新增记录」开始记工时',
              style: TextStyle(fontSize: 13, color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    ScaffoldMessengerState messenger,
    AppSettings settings,
    OvertimeRecord record,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = OvertimeTypes.colorOf(record.type);
    final hours = WorkCalc.hoursOf(record, settings);

    return Dismissible(
      key: ValueKey<int>(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, record),
      onDismissed: (_) {
        ref.read(recordsProvider.notifier).delete(record.id);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '已删除 ${formatDateShort(record.date)} '
              '${record.startTime}-${record.endTime} 的记录',
            ),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () =>
                  ref.read(recordsProvider.notifier).upsert(record),
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          onTap: () => _openEdit(record),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(OvertimeTypes.iconOf(record.type),
                        size: 17, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${formatDateCn(record.date)} ${weekdayCn(record.date)}',
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${record.type} ×${_rateText(record.rate)}',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${record.startTime} - ${record.endTime}'
                      '${record.isCrossDay ? ' 跨天' : ''}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatDuration(record.durationMinutes),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '折算 ${formatHours(hours)} 小时',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (record.project.isNotEmpty || record.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (record.project.isNotEmpty) '项目：${record.project}',
                      if (record.note.isNotEmpty) '备注：${record.note}',
                    ].join('　'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tag(
                      context,
                      text: record.isCompensatory ? '调休' : '加班',
                      color: record.isCompensatory
                          ? const Color(0xFF00897B)
                          : scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    _tag(
                      context,
                      text: record.isSettled ? '已结算' : '未结算',
                      color: record.isSettled
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFB26A00),
                    ),
                    const Spacer(),
                    Text(
                      '预计 ¥${formatMoney(record.amount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: record.isSettled
                            ? scheme.tertiary
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, {required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    OvertimeRecord record,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
          '确定删除 ${formatDateCn(record.date)} '
          '${record.startTime}-${record.endTime} 的加班记录吗？',
        ),
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
  }
}

String _rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
