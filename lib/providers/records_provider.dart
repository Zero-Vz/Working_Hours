import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../core/utils/calc.dart';
import '../data/models/app_settings.dart';
import '../data/models/overtime_record.dart';

/// 加班记录列表（日期倒序、ID 倒序）
final recordsProvider = NotifierProvider<RecordsNotifier, List<OvertimeRecord>>(
  RecordsNotifier.new,
);

class RecordsNotifier extends Notifier<List<OvertimeRecord>> {
  Box<OvertimeRecord> get _box => Hive.box<OvertimeRecord>(BoxNames.records);

  @override
  List<OvertimeRecord> build() => _sorted();

  List<OvertimeRecord> _sorted() {
    final list = _box.values.toList()
      ..sort((a, b) {
        final compare = b.date.compareTo(a.date);
        if (compare != 0) return compare;
        return b.id.compareTo(a.id);
      });
    return List<OvertimeRecord>.unmodifiable(list);
  }

  void refresh() => state = _sorted();

  int _nextId() {
    var max = 0;
    for (final record in _box.values) {
      if (record.id > max) max = record.id;
    }
    return max + 1;
  }

  /// 新增或更新记录（id <= 0 时自动分配新主键）
  Future<void> upsert(OvertimeRecord record) async {
    if (record.id <= 0) record.id = _nextId();
    record.updatedAt = DateTime.now();
    await _box.put(record.id, record);
    refresh();
  }

  /// 删除记录
  Future<void> delete(int id) async {
    await _box.delete(id);
    refresh();
  }

  /// 清空全部记录
  Future<void> clear() async {
    await _box.clear();
    refresh();
  }

  /// 按月批量修改结算状态，返回实际变更条数
  Future<int> setSettledForMonth({
    required int year,
    required int month,
    required bool settled,
  }) async {
    var changed = 0;
    final now = DateTime.now();
    for (final record in _box.values.toList()) {
      if (record.date.year != year || record.date.month != month) continue;
      if (record.isSettled == settled) continue;
      record
        ..isSettled = settled
        ..updatedAt = now;
      await _box.put(record.id, record);
      changed++;
    }
    if (changed > 0) refresh();
    return changed;
  }

  /// 导入记录（按 日期+起止+项目+类型 去重），返回实际新增条数
  Future<int> importRecords(List<OvertimeRecord> incoming) async {
    final existing =
        _box.values.map((record) => record.identityKey).toSet();
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

  /// 设置（时薪 / 休息 / 取整）变化后，按新规则重算全部金额
  Future<void> recalculateAmounts() async {
    final settings = AppSettings.read(Hive.box(BoxNames.settings));
    for (final record in _box.values.toList()) {
      record.amount = WorkCalc.amountOf(record, settings);
      await _box.put(record.id, record);
    }
    refresh();
  }
}
