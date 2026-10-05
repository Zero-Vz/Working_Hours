import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';

/// 加班记录数据模型
///
/// 字段：
/// id, date, startTime, endTime, durationMinutes,
/// type, rate, calcMode, fixedWage, project, note,
/// isCompensatory, isSettled, amount,
/// createdAt, updatedAt
class OvertimeRecord {
  OvertimeRecord({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.type,
    required this.rate,
    this.calcMode = CalcModes.rate,
    this.fixedWage = 0,
    this.project = '',
    this.note = '',
    this.isCompensatory = false,
    this.isSettled = false,
    this.amount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 主键
  int id;

  /// 加班日期（不含时间）
  DateTime date;

  /// 开始时间，格式 "HH:mm"
  String startTime;

  /// 结束时间，格式 "HH:mm"（早于开始时间表示跨天）
  String endTime;

  /// 原始时长（分钟），= 结束 - 开始，跨天 +24 小时
  int durationMinutes;

  /// 加班类型：工作日 / 休息日 / 节假日 / 自定义
  String type;

  /// 倍率（calcMode == rate 时生效）
  double rate;

  /// 计算方式：rate（按倍率）/ fixed（按固定加班时薪）
  String calcMode;

  /// 固定加班时薪（元 / 小时，calcMode == fixed 时生效）
  double fixedWage;

  /// 项目
  String project;

  /// 备注
  String note;

  /// 是否调休
  bool isCompensatory;

  /// 是否已结算
  bool isSettled;

  /// 预计金额（按保存时的设置计算）
  double amount;

  DateTime createdAt;
  DateTime updatedAt;

  /// 是否跨天（结束时间早于等于开始时间）
  bool get isCrossDay => isOvernightRange(startTime, endTime);

  /// 是否按固定加班时薪计算
  bool get isFixedCalc => calcMode == CalcModes.fixed;

  /// 去重用的业务主键
  String get identityKey =>
      '${formatDateKey(date)}|$startTime|$endTime|$project|$type';

  OvertimeRecord copyWith({
    int? id,
    DateTime? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    String? type,
    double? rate,
    String? calcMode,
    double? fixedWage,
    String? project,
    String? note,
    bool? isCompensatory,
    bool? isSettled,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OvertimeRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      rate: rate ?? this.rate,
      calcMode: calcMode ?? this.calcMode,
      fixedWage: fixedWage ?? this.fixedWage,
      project: project ?? this.project,
      note: note ?? this.note,
      isCompensatory: isCompensatory ?? this.isCompensatory,
      isSettled: isSettled ?? this.isSettled,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 手写 TypeAdapter（等价于 hive_generator 生成物，无需 build_runner）
/// 日期时间统一以 ISO 字符串存储，避免平台差异。
class OvertimeRecordAdapter extends TypeAdapter<OvertimeRecord> {
  @override
  final int typeId = 1;

  @override
  OvertimeRecord read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };

    return OvertimeRecord(
      id: fields[0] as int,
      date: DateTime.parse(fields[1] as String),
      startTime: fields[2] as String,
      endTime: fields[3] as String,
      durationMinutes: fields[4] as int,
      type: fields[5] as String,
      rate: (fields[6] as num).toDouble(),
      project: fields[7] as String? ?? '',
      note: fields[8] as String? ?? '',
      isCompensatory: fields[9] as bool? ?? false,
      isSettled: fields[10] as bool? ?? false,
      amount: (fields[11] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(fields[12] as String),
      updatedAt: DateTime.parse(fields[13] as String),
      calcMode: CalcModes.normalize(fields[14] as String?),
      fixedWage: (fields[15] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, OvertimeRecord obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date.toIso8601String())
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.rate)
      ..writeByte(7)
      ..write(obj.project)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.isCompensatory)
      ..writeByte(10)
      ..write(obj.isSettled)
      ..writeByte(11)
      ..write(obj.amount)
      ..writeByte(12)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(13)
      ..write(obj.updatedAt.toIso8601String())
      ..writeByte(14)
      ..write(obj.calcMode)
      ..writeByte(15)
      ..write(obj.fixedWage);
  }
}
