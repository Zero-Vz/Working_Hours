import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';

/// 工资项（自定义）：增项如补贴 / 绩效，扣项如个税 / 保险
///
/// 金额默认为每月固定金额；可对个别月份单独设置（[monthlyOverrides]），
/// 未单独设置的月份仍使用默认金额。
///
/// 字段：id, name, kind, amount, active, createdAt, updatedAt, monthlyOverrides
class IncomeItem {
  IncomeItem({
    required this.id,
    required this.name,
    this.kind = IncomeKinds.income,
    this.amount = 0,
    this.active = true,
    this.monthlyOverrides = const <String, double>{},
    required this.createdAt,
    required this.updatedAt,
  });

  /// 主键
  int id;

  /// 自定义名称（个税、社保、公积金、补贴、绩效…）
  String name;

  /// 类型：income（增项）/ deduct（扣项）
  String kind;

  /// 默认每月金额（元）
  double amount;

  /// 是否启用（停用后不计入统计）
  bool active;

  /// 按月单独设置的金额（键为年月，如 2026-01；缺省月份用 [amount]）
  Map<String, double> monthlyOverrides;

  DateTime createdAt;
  DateTime updatedAt;

  /// 是否为增项
  bool get isIncome => kind != IncomeKinds.deduct;

  /// 是否为扣项
  bool get isDeduct => kind == IncomeKinds.deduct;

  /// 去重用的业务主键
  String get identityKey => '$name|$kind';

  /// 某年月的金额（未单独设置时返回默认金额）
  double amountForYearMonth(int year, int month) =>
      monthlyOverrides[yearMonthKey(year, month)] ?? amount;

  /// 某月的金额
  double amountFor(YearMonth key) => amountForYearMonth(key.year, key.month);

  /// 是否对某年月单独设置了金额
  bool hasOverride(int year, int month) =>
      monthlyOverrides.containsKey(yearMonthKey(year, month));

  /// 对统计生效的金额（增项为正、扣项为负，停用为 0）
  double get signedAmount => signedAmountForYearMonth(
        DateTime.now().year,
        DateTime.now().month,
      );

  /// 某年月对统计生效的金额
  double signedAmountForYearMonth(int year, int month) {
    if (!active) return 0;
    final value = amountForYearMonth(year, month);
    return isIncome ? value : -value;
  }

  IncomeItem copyWith({
    int? id,
    String? name,
    String? kind,
    double? amount,
    bool? active,
    Map<String, double>? monthlyOverrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncomeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      active: active ?? this.active,
      monthlyOverrides: monthlyOverrides ?? this.monthlyOverrides,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 手写 TypeAdapter（等价于 hive_generator 生成物）
class IncomeItemAdapter extends TypeAdapter<IncomeItem> {
  @override
  final int typeId = 3;

  @override
  IncomeItem read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };

    return IncomeItem(
      id: fields[0] as int,
      name: fields[1] as String? ?? '',
      kind: fields[2] as String? ?? IncomeKinds.income,
      amount: (fields[3] as num?)?.toDouble() ?? 0,
      active: fields[4] as bool? ?? true,
      createdAt: DateTime.parse(fields[5] as String),
      updatedAt: DateTime.parse(fields[6] as String),
      monthlyOverrides: _readOverrides(fields[7]),
    );
  }

  @override
  void write(BinaryWriter writer, IncomeItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.active)
      ..writeByte(5)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(6)
      ..write(obj.updatedAt.toIso8601String())
      ..writeByte(7)
      ..write(obj.monthlyOverrides);
  }

  /// 解析按月金额（兼容旧数据缺失该字段）
  static Map<String, double> _readOverrides(dynamic raw) {
    if (raw is! Map) return const <String, double>{};
    final result = <String, double>{};
    raw.forEach((key, value) {
      final amount = (value as num?)?.toDouble();
      if (key is String && amount != null) result[key] = amount;
    });
    return result;
  }
}
