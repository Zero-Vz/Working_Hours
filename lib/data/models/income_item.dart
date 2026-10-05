import 'package:hive/hive.dart';

import '../../core/constants.dart';

/// 工资项（自定义）：增项如补贴 / 绩效，扣项如个税 / 保险
///
/// 金额为每月固定金额，按月计入统计。
///
/// 字段：id, name, kind, amount, active, createdAt, updatedAt
class IncomeItem {
  IncomeItem({
    required this.id,
    required this.name,
    this.kind = IncomeKinds.income,
    this.amount = 0,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 主键
  int id;

  /// 自定义名称（个税、社保、公积金、补贴、绩效…）
  String name;

  /// 类型：income（增项）/ deduct（扣项）
  String kind;

  /// 每月金额（元）
  double amount;

  /// 是否启用（停用后不计入统计）
  bool active;

  DateTime createdAt;
  DateTime updatedAt;

  /// 是否为增项
  bool get isIncome => kind != IncomeKinds.deduct;

  /// 是否为扣项
  bool get isDeduct => kind == IncomeKinds.deduct;

  /// 去重用的业务主键
  String get identityKey => '$name|$kind';

  /// 对统计生效的金额（增项为正、扣项为负，停用为 0）
  double get signedAmount {
    if (!active) return 0;
    return isIncome ? amount : -amount;
  }

  IncomeItem copyWith({
    int? id,
    String? name,
    String? kind,
    double? amount,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncomeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      active: active ?? this.active,
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
    );
  }

  @override
  void write(BinaryWriter writer, IncomeItem obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.updatedAt.toIso8601String());
  }
}
