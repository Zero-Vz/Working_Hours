import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/time_utils.dart';
import '../models/overtime_record.dart';

/// CSV 导出 / 导入（全部本地完成，不联网）
class RecordCsvService {
  const RecordCsvService._();

  static const List<String> headers = <String>[
    'id',
    'date',
    'startTime',
    'endTime',
    'durationMinutes',
    'type',
    'rate',
    'project',
    'note',
    'isCompensatory',
    'isSettled',
    'amount',
    'createdAt',
    'updatedAt',
  ];

  /// UTF-8 BOM，保证 Excel 正确识别中文
  static const String _bom = '\uFEFF';

  /// 生成 CSV 文本
  static String exportToString(List<OvertimeRecord> records) {
    final rows = <List<dynamic>>[List<dynamic>.of(headers)];
    for (final record in records) {
      rows.add(<dynamic>[
        record.id,
        formatDateKey(record.date),
        record.startTime,
        record.endTime,
        record.durationMinutes,
        record.type,
        record.rate,
        record.project,
        record.note,
        record.isCompensatory,
        record.isSettled,
        record.amount,
        record.createdAt.toIso8601String(),
        record.updatedAt.toIso8601String(),
      ]);
    }
    return '$_bom${const ListToCsvConverter().convert(rows)}';
  }

  /// 导出到临时目录并调用系统分享面板
  static Future<File> exportAndShare(List<OvertimeRecord> records) async {
    final content = exportToString(records);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/记工时_$stamp.csv');
    await file.writeAsString(content, flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'text/csv')],
      text: '记工时 - 加班记录导出（共 ${records.length} 条）',
    );
    return file;
  }

  /// 选择本地 CSV 并解析，返回 null 表示用户取消了选择
  static Future<List<OvertimeRecord>?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final String text;
    if (picked.bytes != null) {
      text = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      text = await File(picked.path!).readAsString();
    } else {
      throw const FormatException('无法读取所选文件');
    }
    return parse(text);
  }

  /// 解析 CSV 文本
  static List<OvertimeRecord> parse(String rawText) {
    var text = rawText;
    if (text.startsWith(_bom)) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty) throw const FormatException('文件内容为空');

    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(text)
        .where((row) => row.any((cell) => _str(cell).isNotEmpty))
        .toList();
    if (rows.isEmpty) throw const FormatException('文件内容为空');

    final header = rows.first.map((cell) => _str(cell)).toList();
    if (!header.map((cell) => cell.toLowerCase()).contains('id')) {
      throw const FormatException('缺少表头，无法识别该 CSV 文件');
    }

    int column(String name) =>
        header.indexWhere((cell) => cell.toLowerCase() == name.toLowerCase());

    String value(List<dynamic> row, String name) {
      final index = column(name);
      if (index < 0 || index >= row.length) return '';
      return _str(row[index]);
    }

    final now = DateTime.now();
    final records = <OvertimeRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final date = DateTime.tryParse(value(row, 'date'));
      final start = value(row, 'startTime');
      final end = value(row, 'endTime');
      if (date == null || start.isEmpty || end.isEmpty) continue;
      if (parseTimeToMinutes(start) == null ||
          parseTimeToMinutes(end) == null) {
        continue;
      }

      records.add(
        OvertimeRecord(
          id: int.tryParse(value(row, 'id')) ?? 0,
          date: dateOnly(date),
          startTime: start,
          endTime: end,
          durationMinutes: int.tryParse(value(row, 'durationMinutes')) ??
              calcDurationMinutes(start, end),
          type: value(row, 'type').isEmpty ? '工作日' : value(row, 'type'),
          rate: double.tryParse(value(row, 'rate')) ?? 1.5,
          project: value(row, 'project'),
          note: value(row, 'note'),
          isCompensatory: _bool(value(row, 'isCompensatory')),
          isSettled: _bool(value(row, 'isSettled')),
          amount: double.tryParse(value(row, 'amount')) ?? 0,
          createdAt: DateTime.tryParse(value(row, 'createdAt')) ?? now,
          updatedAt: DateTime.tryParse(value(row, 'updatedAt')) ?? now,
        ),
      );
    }
    if (records.isEmpty) throw const FormatException('未解析到有效记录');
    return records;
  }

  static String _str(dynamic value) =>
      value == null ? '' : value.toString().trim();

  static bool _bool(String value) {
    final text = value.toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
