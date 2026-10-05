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

/// 记录列表页：按天 / 按月筛选、按项目搜索、左滑删除、点击编辑、按月批量结算
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

  String _labelOf(RecordFilter filter) => filter.byDay
      ? '${formatDateCn(filter.date)} ${weekdayCn(filter.date)}'
      : formatMonthCn(filter.date);

  /// ‹ / › 按天或按月移动
  void _shift(int delta) {
    final filter = ref.read(recordFilterProvider);
    if (filter.byDay) {
      final next = DateTime(
        filter.date.year,
        filter.date.month,
        filter.date.day + delta,
      );
      ref.read(recordFilterProvider.notifier).state =
          filter.copyWith(date: dateOnly(next));
    } else {
      final next = DateTime(filter.date.year, filter.date.month + delta);
      ref.read(recordFilterProvider.notifier).state =
          filter.copyWith(date: dateOnly(next));
    }
  }

  /// 选择精确日期（选中后按“当天”查看）
  Future<void> _pickDate(RecordFilter filter) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.date,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    ref.read(recordFilterProvider.notifier).state =
        filter.copyWith(date: dateOnly(picked), byDay: true);
  }

  /// 当天 ↔ 当月 切换
  void _toggleMode(RecordFilter filter) {
    if (filter.byDay) {
      ref.read(recordFilterProvider.notifier).state =
          filter.copyWith(byDay: false);
      return;
    }
    final today = dateOnly(DateTime.now());
    final sameMonth =
        today.year == filter.date.year && today.month == filter.date.month;
    ref.read(recordFilterProvider.notifier).state = filter.copyWith(
      date: sameMonth ? today : DateTime(filter.date.year, filter.date.month, 1),
      byDay: true,
    );
  }

  Future<void> _openEdit(OvertimeRecord? record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordEditPage(record: record),
      ),
    );
  }

  /// 按月批量修改结算状态
  Future<void> _openBatchSettle(RecordFilter filter) async {
    final month = filter.month;
    final stats = ref.read(monthlyStatsProvider(month));
    final messenger = ScaffoldMessenger.of(context);
    if (stats.count == 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${formatMonthCn(month.date)}暂无记录')),
        );
      return;
    }

    final settled = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('按月结算'),
        content: Text(
          '${formatMonthCn(month.date)} 共 ${stats.count} 条记录，'
          '合计 ¥${formatMoney(stats.amount)}。\n\n'
          '将该月全部记录批量改为已结算 / 未结算？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('全部未结算'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('全部已结算'),
          ),
        ],
      ),
    );
    if (settled == null) return;

    final changed = await ref
        .read(recordsProvider.notifier)
        .setSettledForMonth(
          year: month.year,
          month: month.month,
          settled: settled,
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            changed == 0
                ? '该月记录状态无需变更'
                : '已将 ${formatMonthCn(month.date)} 的 $changed 条记录'
                    '${settled ? '标记为已结算' : '改为未结算'}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filter = ref.watch(recordFilterProvider);
    final query = ref.watch(searchQueryProvider);
    final records = ref.watch(filteredRecordsProvider);
    final settings = ref.watch(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final summary = _Summary.of(records, settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记工时'),
        actions: [
          IconButton(
            tooltip: '按月批量结算',
            icon: const Icon(Icons.published_with_changes_outlined),
            onPressed: () => _openBatchSettle(filter),
          ),
          IconButton(
            tooltip: '选择日期',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _pickDate(filter),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(filter, query, summary),
          Expanded(
            child: records.isEmpty
                ? _buildEmpty(scheme, query.trim().isNotEmpty, filter)
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

  Widget _buildFilterBar(
    RecordFilter filter,
    String query,
    _Summary summary,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: filter.byDay ? '前一天' : '上一月',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _pickDate(filter),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _labelOf(filter),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: filter.byDay ? '后一天' : '下一月',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: filter.byDay ? '改为按月查看' : '改为按天查看',
                icon: Icon(
                  filter.byDay
                      ? Icons.calendar_month_outlined
                      : Icons.event_outlined,
                  size: 21,
                ),
                color: scheme.primary,
                onPressed: () => _toggleMode(filter),
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
          _buildSummary(scheme, summary, filter),
        ],
      ),
    );
  }

  Widget _buildSummary(
    ColorScheme scheme,
    _Summary summary,
    RecordFilter filter,
  ) {
    return Container(
      width: double.infinity,
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
            filter.byDay ? '当天 ${summary.count} 条' : '共 ${summary.count} 条',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          Text(
            '时长 ${formatDuration(summary.effectiveMinutes)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (summary.deductedMinutes > 0)
            Text(
              '（已扣休息 ${summary.deductedMinutes} 分）',
              style: TextStyle(fontSize: 12, color: scheme.tertiary),
            ),
          Text(
            '折算 ${formatHours(summary.hours)} 小时',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          Text(
            '预计 ¥${formatMoney(summary.amount)}',
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

  Widget _buildEmpty(ColorScheme scheme, bool searching, RecordFilter filter) {
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
            searching
                ? '没有匹配的记录'
                : filter.byDay
                    ? '当天还没有加班记录'
                    : '本月还没有加班记录',
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
    final effective = WorkCalc.effectiveMinutes(
      record.durationMinutes,
      deductBreak: settings.deductBreak,
      breakMinutes: settings.breakMinutes,
    );
    final deducted = record.durationMinutes - effective;

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
                        record.isFixedCalc
                            ? '${record.type} ¥${formatMoney(record.fixedWage)}/时'
                            : '${record.type} ×${_rateText(record.rate)}',
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
                      formatDuration(effective),
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
                if (deducted > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '原始 ${formatDuration(record.durationMinutes)}'
                    '　已扣休息 $deducted 分钟',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
                ],
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

/// 当前筛选结果的汇总
class _Summary {
  const _Summary({
    required this.count,
    required this.rawMinutes,
    required this.deductedMinutes,
    required this.hours,
    required this.amount,
  });

  final int count;
  final int rawMinutes;
  final int deductedMinutes;
  final double hours;
  final double amount;

  int get effectiveMinutes => rawMinutes - deductedMinutes;

  factory _Summary.of(List<OvertimeRecord> records, AppSettings settings) {
    var raw = 0;
    var deducted = 0;
    var hours = 0.0;
    var amount = 0.0;
    for (final record in records) {
      final effective = WorkCalc.effectiveMinutes(
        record.durationMinutes,
        deductBreak: settings.deductBreak,
        breakMinutes: settings.breakMinutes,
      );
      raw += record.durationMinutes;
      deducted += record.durationMinutes - effective;
      hours += WorkCalc.hoursOf(record, settings);
      amount += WorkCalc.amountOf(record, settings);
    }
    return _Summary(
      count: records.length,
      rawMinutes: raw,
      deductedMinutes: deducted,
      hours: hours,
      amount: amount,
    );
  }
}

String _rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
