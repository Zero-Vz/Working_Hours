import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/overtime_record.dart';
import 'records_provider.dart';

/// 当前筛选的月份（每月 1 日）
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 项目搜索关键字
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 月份 + 关键字过滤后的记录（日期倒序）
final filteredRecordsProvider = Provider<List<OvertimeRecord>>((ref) {
  final records = ref.watch(recordsProvider);
  final month = ref.watch(selectedMonthProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return records.where((record) {
    if (record.date.year != month.year || record.date.month != month.month) {
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
