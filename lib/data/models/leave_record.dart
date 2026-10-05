import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';

/// 请假记录数据模型
///
/// 字段：id, date, days, type, reason, deductAmount, createdAt, updatedAt
class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.date,
    this.days = 1,
    this.type = LeaveTypes.paid,
    this.reason = '',
    this.deductAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 主键
  int id;

  /// 请假日期（不含时间）
  DateTime date;

  /// 请假时长（天，支持 0.5 天）
  double days;

  /// 请假类型：带薪 / 无薪
  String type;

  /// 请假理由
  String reason;

  /// 扣工资金额（元）。带薪请假恒为 0（不扣除）
  double deductAmount;

  DateTime createdAt;
  DateTime updatedAt;

  /// 是否带薪
  bool get isPaid => LeaveTypes.isPaid(type);

  /// 实际扣除金额（带薪恒为 0）
  double get actualDeduct => isPaid ? 0 : deductAmount;

  /// 去重用的业务主键
  String get identityKey => '${formatDateKey(date)}|$type|$reason|$days';

  LeaveRecord copyWith({
    int? id,
    DateTime? date,
    double? days,
    String? type,
    String? reason,
    double? deductAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      days: days ?? this.days,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      deductAmount: deductAmount ?? this.deductAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 手写 TypeAdapter（等价于 hive_generator 生成物）
class LeaveRecordAdapter extends TypeAdapter<LeaveRecord> {
  @override
  final int typeId = 2;

  @override
  LeaveRecord read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };

    return LeaveRecord(
      id: fields[0] as int,
      date: DateTime.parse(fields[1] as String),
      days: (fields[2] as num?)?.toDouble() ?? 1,
      type: fields[3] as String? ?? LeaveTypes.paid,
      reason: fields[4] as String? ?? '',
      deductAmount: (fields[5] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(fields[6] as String),
      updatedAt: DateTime.parse(fields[7] as String),
    );
  }

  @override
  void write(BinaryWriter writer, LeaveRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date.toIso8601String())
      ..writeByte(2)
      ..write(obj.days)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.deductAmount)
      ..writeByte(6)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(7)
      ..write(obj.updatedAt.toIso8601String());
  }
}
