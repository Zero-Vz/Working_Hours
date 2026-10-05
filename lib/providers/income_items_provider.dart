import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../core/utils/time_utils.dart';
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

  /// 导入工资项（按名称 + 类型去重），返回实际新增条数
  Future<int> importItems(List<IncomeItem> items) async {
    final existingKeys = <String>{
      for (final item in _box.values) item.identityKey,
    };
    var added = 0;
    for (final item in items) {
      if (existingKeys.contains(item.identityKey)) continue;
      item.id = _nextId();
      item.updatedAt = DateTime.now();
      await _box.put(item.id, item);
      existingKeys.add(item.identityKey);
      added++;
    }
    refresh();
    return added;
  }
}

/// 某期间的工资项合计（增项 / 扣项）
class IncomeTotals {
  const IncomeTotals({required this.extra, required this.deduct});

  /// 增项合计
  final double extra;

  /// 扣项合计
  final double deduct;

  /// 净额 = 增项 - 扣项
  double get net => extra - deduct;
}

/// 单月生效的工资项合计（会取该月的按月金额）
final monthIncomeTotalsProvider =
    Provider.family<IncomeTotals, YearMonth>((ref, key) {
  var extra = 0.0;
  var deduct = 0.0;
  for (final item in ref.watch(incomeItemsProvider)) {
    if (!item.active) continue;
    final value = item.amountFor(key);
    if (item.isIncome) {
      extra += value;
    } else {
      deduct += value;
    }
  }
  return IncomeTotals(extra: extra, deduct: deduct);
});

/// 全年生效的工资项合计（12 个月逐月累加）
final yearIncomeTotalsProvider =
    Provider.family<IncomeTotals, int>((ref, year) {
  var extra = 0.0;
  var deduct = 0.0;
  for (var month = 1; month <= 12; month++) {
    final totals =
        ref.watch(monthIncomeTotalsProvider(YearMonth(year, month)));
    extra += totals.extra;
    deduct += totals.deduct;
  }
  return IncomeTotals(extra: extra, deduct: deduct);
});

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
