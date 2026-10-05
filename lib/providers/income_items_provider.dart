import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../data/models/income_item.dart';

/// 工资项列表（增项在前、扣项在后，同组按创建时间）
final incomeItemsProvider =
    NotifierProvider<IncomeItemsNotifier, List<IncomeItem>>(
  IncomeItemsNotifier.new,
);

class IncomeItemsNotifier extends Notifier<List<IncomeItem>> {
  Box<IncomeItem> get _box => Hive.box<IncomeItem>(BoxNames.incomeItems);

  @override
  List<IncomeItem> build() => _sorted();

  List<IncomeItem> _sorted() {
    final list = _box.values.toList()
      ..sort((a, b) {
        if (a.kind != b.kind) return a.kind == IncomeKinds.income ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    return List<IncomeItem>.unmodifiable(list);
  }

  void refresh() => state = _sorted();

  int _nextId() {
    var max = 0;
    for (final item in _box.values) {
      if (item.id > max) max = item.id;
    }
    return max + 1;
  }

  /// 新增或更新（id <= 0 时自动分配新主键）
  Future<void> upsert(IncomeItem item) async {
    if (item.id <= 0) item.id = _nextId();
    item.updatedAt = DateTime.now();
    await _box.put(item.id, item);
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
}

/// 启用中的增项合计（每月）
final incomeExtraTotalProvider = Provider<double>((ref) {
  var total = 0.0;
  for (final item in ref.watch(incomeItemsProvider)) {
    if (item.isIncome && item.active) total += item.amount;
  }
  return total;
});

/// 启用中的扣项合计（每月）
final incomeDeductTotalProvider = Provider<double>((ref) {
  var total = 0.0;
  for (final item in ref.watch(incomeItemsProvider)) {
    if (item.isDeduct && item.active) total += item.amount;
  }
  return total;
});
