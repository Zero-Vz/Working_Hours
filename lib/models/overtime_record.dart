import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// 加班类型枚举
enum OvertimeType {
  workday('工作日', 1.5),
  restday('休息日', 2.0),
  holiday('节假日', 3.0);

  final String label;
  final double defaultRate;
  const OvertimeType(this.label, this.defaultRate);
}

/// 加班记录数据模型
class OvertimeRecord {
  final String id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int durationMinutes;
  final OvertimeType type;
  final double rate;
  final String project;
  final String note;
  final bool isCompensatory;
  final bool isSettled;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  OvertimeRecord({
    String? id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.type,
    required this.rate,
    this.project = '',
    this.note = '',
    this.isCompensatory = false,
    this.isSettled = false,
    required this.amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从数据库Map创建
  factory OvertimeRecord.fromMap(Map<String, dynamic> map) {
    return OvertimeRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      startTime: _parseTime(map['start_time'] as String),
      endTime: _parseTime(map['end_time'] as String),
      durationMinutes: map['duration_minutes'] as int,
      type: OvertimeType.values[map['type_index'] as int],
      rate: (map['rate'] as num).toDouble(),
      project: map['project'] as String? ?? '',
      note: map['note'] as String? ?? '',
      isCompensatory: (map['is_compensatory'] as int) == 1,
      isSettled: (map['is_settled'] as int) == 1,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T').first,
      'start_time': _formatTime(startTime),
      'end_time': _formatTime(endTime),
      'duration_minutes': durationMinutes,
      'type_index': type.index,
      'rate': rate,
      'project': project,
      'note': note,
      'is_compensatory': isCompensatory ? 1 : 0,
      'is_settled': isSettled ? 1 : 0,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// 复制并修改部分字段
  OvertimeRecord copyWith({
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? durationMinutes,
    OvertimeType? type,
    double? rate,
    String? project,
    String? note,
    bool? isCompensatory,
    bool? isSettled,
    double? amount,
  }) {
    return OvertimeRecord(
      id: id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      rate: rate ?? this.rate,
      project: project ?? this.project,
      note: note ?? this.note,
      isCompensatory: isCompensatory ?? this.isCompensatory,
      isSettled: isSettled ?? this.isSettled,
      amount: amount ?? this.amount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}