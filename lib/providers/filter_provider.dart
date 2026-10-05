import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/utils/time_utils.dart';
import '../data/models/leave_record.dart';
import '../data/models/overtime_record.dart';
import 'leaves_provider.dart';
import 'records_provider.dart';

/// 记录筛选条件：
/// - [byDay] = false：按整月筛选（date 只取年月）
/// - [byDay] = true：精确到某一天
class RecordFilter {
  const RecordFilter({required this.date, this.byDay = false});

  /// 筛选日期（无时间部分）
  final DateTime date;

  /// 是否精确到天
  final bool byDay;

  YearMonth get month => YearMonth.of(date);

  /// 切换到月份视图（保留当前年月）
  DateTime get monthAnchor => DateTime(date.year, date.month);

  RecordFilter copyWith({DateTime? date, bool? byDay}) => RecordFilter(
        date: date ?? this.date,
        byDay: byDay ?? this.byDay,
      );
}

/// 当前筛选条件（默认：今天，按月查看）
final recordFilterProvider = StateProvider<RecordFilter>((ref) {
  return RecordFilter(date: dateOnly(DateTime.now()));
});

/// 项目搜索关键字
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 筛选条件 + 关键字过滤后的记录（日期倒序）
final filteredRecordsProvider = Provider<List<OvertimeRecord>>((ref) {
  final records = ref.watch(recordsProvider);
  final filter = ref.watch(recordFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return records.where((record) {
    if (filter.byDay) {
      if (record.date.year != filter.date.year ||
          record.date.month != filter.date.month ||
          record.date.day != filter.date.day) {
        return false;
      }
    } else if (record.date.year != filter.date.year ||
        record.date.month != filter.date.month) {
      return false;
    }
    if (query.isEmpty) return true;
    return record.project.toLowerCase().contains(query) ||
        record.note.toLowerCase().contains(query) ||
        record.type.toLowerCase().contains(query);
  }).toList();
});

/// 已出现过的项目名（用于搜索建议与快速选择）
final projectsProvider = Provider<List<String>>((ref) {
  final records = ref.watch(recordsProvider);
  final set = <String>{};
  for (final record in records) {
    final project = record.project.trim();
    if (project.isNotEmpty) set.add(project);
  }
  final list = set.toList()..sort();
  return list;
});

/// 记录页当前展示的大类：加班记录 / 请假记录
final recordKindProvider = StateProvider<String>(
  (ref) => RecordKinds.overtime,
);

/// 筛选条件 + 关键字过滤后的请假记录（日期倒序）
final filteredLeavesProvider = Provider<List<LeaveRecord>>((ref) {
  final leaves = ref.watch(leavesProvider);
  final filter = ref.watch(recordFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return leaves.where((record) {
    if (filter.byDay) {
      if (record.date.year != filter.date.year ||
          record.date.month != filter.date.month ||
          record.date.day != filter.date.day) {
        return false;
      }
    } else if (record.date.year != filter.date.year ||
        record.date.month != filter.date.month) {
      return false;
    }
    if (query.isEmpty) return true;
    return record.reason.toLowerCase().contains(query) ||
        LeaveTypes.labelOf(record.type).contains(query);
  }).toList();
});
