import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../data/models/leave_record.dart';

/// 请假记录列表（日期倒序、ID 倒序）
final leavesProvider = NotifierProvider<LeavesNotifier, List<LeaveRecord>>(
  LeavesNotifier.new,
);

class LeavesNotifier extends Notifier<List<LeaveRecord>> {
  Box<LeaveRecord> get _box => Hive.box<LeaveRecord>(BoxNames.leaves);

  @override
  List<LeaveRecord> build() => _sorted();

  List<LeaveRecord> _sorted() {
    final list = _box.values.toList()
      ..sort((a, b) {
        final compare = b.date.compareTo(a.date);
        if (compare != 0) return compare;
        return b.id.compareTo(a.id);
      });
    return List<LeaveRecord>.unmodifiable(list);
  }

  void refresh() => state = _sorted();

  int _nextId() {
    var max = 0;
    for (final record in _box.values) {
      if (record.id > max) max = record.id;
    }
    return max + 1;
  }

  /// 新增或更新（id <= 0 时自动分配新主键）
  Future<void> upsert(LeaveRecord record) async {
    if (record.id <= 0) record.id = _nextId();
    record.updatedAt = DateTime.now();
    await _box.put(record.id, record);
    refresh();
  }

  /// 删除
  Future<void> delete(int id) async {
    await _box.delete(id);
    refresh();
  }

  /// 清空全部
  Future<void> clear() async {
    await _box.clear();
    refresh();
  }

  /// 导入（按 日期+类型+理由+天数 去重），返回实际新增条数
  Future<int> importLeaves(List<LeaveRecord> incoming) async {
    final existing = _box.values.map((record) => record.identityKey).toSet();
    var nextId = _nextId();
    var added = 0;
    for (final record in incoming) {
      if (existing.contains(record.identityKey)) continue;
      record.id = nextId++;
      await _box.put(record.id, record);
      existing.add(record.identityKey);
      added++;
    }
    if (added > 0) refresh();
    return added;
  }
}
