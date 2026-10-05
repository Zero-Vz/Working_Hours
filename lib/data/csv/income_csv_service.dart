import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../models/income_item.dart';

/// 工资项 CSV 导出 / 导入（全部本地完成，不联网）
class IncomeCsvService {
  const IncomeCsvService._();

  static const List<String> headers = <String>[
    'id',
    'name',
    'kind',
    'amount',
    'active',
    'monthlyOverrides',
    'createdAt',
    'updatedAt',
  ];

  /// UTF-8 BOM，保证 Excel 正确识别中文
  static const String _bom = '\uFEFF';

  /// 按月金额序列化：2026-01=12000;2026-02=13000
  static String encodeOverrides(Map<String, double> overrides) => [
        for (final entry in overrides.entries) '${entry.key}=${entry.value}',
      ].join(';');

  /// 解析按月金额列
  static Map<String, double> decodeOverrides(String raw) {
    final result = <String, double>{};
    for (final pair in raw.split(';')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final key = pair.substring(0, index).trim();
      final value = double.tryParse(pair.substring(index + 1).trim());
      if (key.isEmpty || value == null) continue;
      if (parseYearMonthKey(key) == null) continue;
      result[key] = value;
    }
    return result;
  }

  /// 生成 CSV 文本
  static String exportToString(List<IncomeItem> items) {
    final rows = <List<dynamic>>[List<dynamic>.of(headers)];
    for (final item in items) {
      rows.add(<dynamic>[
        item.id,
        item.name,
        item.kind,
        item.amount,
        item.active,
        encodeOverrides(item.monthlyOverrides),
        item.createdAt.toIso8601String(),
        item.updatedAt.toIso8601String(),
      ]);
    }
    return '$_bom${const ListToCsvConverter().convert(rows)}';
  }

  /// 导出到临时目录并调用系统分享面板
  static Future<File> exportAndShare(List<IncomeItem> items) async {
    final content = exportToString(items);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/记工时_工资项_$stamp.csv');
    await file.writeAsString(content, flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'text/csv')],
      text: '记工时 - 工资项导出（共 ${items.length} 项）',
    );
    return file;
  }

  /// 选择本地 CSV 并解析，返回 null 表示用户取消了选择
  static Future<List<IncomeItem>?> pickAndParse() async {
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
  static List<IncomeItem> parse(String rawText) {
    var text = rawText;
    if (text.startsWith(_bom)) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty) throw const FormatException('文件内容为空');

    List<List<dynamic>> convert(String eol) =>
        CsvToListConverter(shouldParseNumbers: false, eol: eol)
            .convert(text)
            .where((row) => row.any((cell) => _str(cell).isNotEmpty))
            .toList();

    var rows = convert('\r\n');
    if (rows.length < 2 && text.contains('\n')) {
      final lfRows = convert('\n');
      if (lfRows.length > rows.length) rows = lfRows;
    }
    if (rows.isEmpty) throw const FormatException('文件内容为空');

    final header = rows.first.map((cell) => _str(cell)).toList();
    if (!header.map((cell) => cell.toLowerCase()).contains('name')) {
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
    final items = <IncomeItem>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = value(row, 'name');
      if (name.isEmpty) continue;

      items.add(
        IncomeItem(
          id: int.tryParse(value(row, 'id')) ?? 0,
          name: name,
          kind: value(row, 'kind') == IncomeKinds.deduct
              ? IncomeKinds.deduct
              : IncomeKinds.income,
          amount: double.tryParse(value(row, 'amount')) ?? 0,
          active: value(row, 'active').toLowerCase() != 'false',
          monthlyOverrides: decodeOverrides(value(row, 'monthlyOverrides')),
          createdAt: DateTime.tryParse(value(row, 'createdAt')) ?? now,
          updatedAt: DateTime.tryParse(value(row, 'updatedAt')) ?? now,
        ),
      );
    }
    if (items.isEmpty) throw const FormatException('未解析到有效记录');
    return items;
  }

  static String _str(dynamic value) =>
      value == null ? '' : value.toString().trim();
}
