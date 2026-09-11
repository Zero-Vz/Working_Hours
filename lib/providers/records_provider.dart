import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/overtime_record.dart';

/// 所有加班记录
final allRecordsProvider = FutureProvider<List<OvertimeRecord>>((ref) async {
  final db = DatabaseHelper.instance;
  return db.getAllRecords();
});

/// 当前选中的年月状态
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// 按月筛选的记录
final monthlyRecordsProvider = FutureProvider<List<OvertimeRecord>>((ref) async {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final db = DatabaseHelper.instance;
  return db.getRecordsByMonth(selectedMonth.year, selectedMonth.month);
});

/// 搜索关键词
final searchKeywordProvider = StateProvider<String>((ref) => '');

/// 搜索结果
final searchResultsProvider = FutureProvider<List<OvertimeRecord>>((ref) async {
  final keyword = ref.watch(searchKeywordProvider);
  if (keyword.isEmpty) return [];
  final db = DatabaseHelper.instance;
  return db.searchByProject(keyword);
});

/// 记录操作Notifier
class RecordsNotifier extends StateNotifier<AsyncValue<List<OvertimeRecord>>> {
  RecordsNotifier() : super(const AsyncValue.loading());

  Future<void> loadAll() async {
    try {
      final db = DatabaseHelper.instance;
      final records = await db.getAllRecords();
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addRecord(OvertimeRecord record) async {
    try {
      final db = DatabaseHelper.instance;
      await db.insertRecord(record);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRecord(OvertimeRecord record) async {
    try {
      final db = DatabaseHelper.instance;
      await db.updateRecord(record);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteRecord(id);
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAllRecords() async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteAllRecords();
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importRecords(List<OvertimeRecord> records) async {
    try {
      final db = DatabaseHelper.instance;
      for (final record in records) {
        await db.insertRecord(record);
      }
      await loadAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recordsProvider = StateNotifierProvider<RecordsNotifier, AsyncValue<List<OvertimeRecord>>>((ref) {
  return RecordsNotifier()..loadAll();
});