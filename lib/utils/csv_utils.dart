import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/overtime_record.dart';
import 'calculations.dart';

/// CSV导入导出工具类
class CsvUtils {
  /// 导出记录为CSV字符串
  static String exportToCsv(List<OvertimeRecord> records) {
    final headers = [
      '日期', '开始时间', '结束时间', '时长(分钟)', '加班类型',
      '倍率', '项目', '备注', '是否调休', '是否已结算',
      '折算工时', '预计金额',
    ];

    final rows = <List<String>>[headers];

    for (final record in records) {
      final convertedHours = Calculations.calculateConvertedHours(
        record.durationMinutes, record.rate,
      );
      rows.add([
        DateFormat('yyyy-MM-dd').format(record.date),
        Calculations.formatTimeOfDay(record.startTime),
        Calculations.formatTimeOfDay(record.endTime),
        record.durationMinutes.toString(),
        record.type.label,
        record.rate.toString(),
        record.project,
        record.note,
        record.isCompensatory ? '是' : '否',
        record.isSettled ? '是' : '否',
        convertedHours.toStringAsFixed(2),
        record.amount.toStringAsFixed(2),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// 保存CSV到文件并返回文件路径
  static Future<String> saveCsvToFile(String csvContent, {String? fileName}) async {
    final directory = await getTemporaryDirectory();
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final name = fileName ?? '加班记录_$now.csv';
    final file = File('${directory.path}/$name');
    await file.writeAsString('\uFEFF$csvContent', encoding: utf8);
    return file.path;
  }

  /// 从CSV文件导入记录
  static Future<List<OvertimeRecord>> importFromCsv(String csvContent) async {
    final rows = const CsvToListConverter(fieldDelimiter: ',').convert(csvContent);
    if (rows.isEmpty) return [];

    final records = <OvertimeRecord>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 12) continue;

      try {
        final dateStr = row[0].toString().trim();
        final startTimeStr = row[1].toString().trim();
        final endTimeStr = row[2].toString().trim();
        final durationMinutes = int.tryParse(row[3].toString().trim()) ?? 0;
        final typeLabel = row[4].toString().trim();
        final rate = double.tryParse(row[5].toString().trim()) ?? 1.5;
        final project = row[6].toString().trim();
        final note = row[7].toString().trim();
        final isCompensatory = row[8].toString().trim() == '是';
        final isSettled = row[9].toString().trim() == '是';

        final date = DateTime.parse(dateStr);
        final startTime = _parseTime(startTimeStr);
        final endTime = _parseTime(endTimeStr);
        final type = OvertimeType.values.firstWhere(
          (t) => t.label == typeLabel,
          orElse: () => OvertimeType.workday,
        );
        final amount = double.tryParse(row[11].toString().trim()) ?? 0.0;

        records.add(OvertimeRecord(
          date: date,
          startTime: startTime,
          endTime: endTime,
          durationMinutes: durationMinutes,
          type: type,
          rate: rate,
          project: project,
          note: note,
          isCompensatory: isCompensatory,
          isSettled: isSettled,
          amount: amount,
        ));
      } catch (e) {
        continue;
      }
    }
    return records;
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}