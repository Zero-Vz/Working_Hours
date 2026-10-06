import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/holidays.dart';
import 'http_service.dart';

/// 节假日文件解析结果
class HolidayParseResult {
  const HolidayParseResult({
    required this.data,
    this.name = '',
    this.ignored = 0,
  });

  /// 解析出的数据
  final HolidayData data;

  /// 文件 / 远端声明的名称（JSON 的 name、CSV 的文件名）
  final String name;

  /// 被忽略的非法条目数
  final int ignored;

  bool get isEmpty => data.isEmpty;
}

/// 节假日数据的导入导出（JSON / CSV 均可），以及联网更新
///
/// JSON 示例：
/// ```json
/// {
///   "name": "2027年放假安排",
///   "statutory": ["2027-01-01"],
///   "makeup": ["2027-01-24"],
///   "breaks": ["2027-01-01..2027-01-03"]
/// }
/// ```
///
/// CSV 示例（`kind,date[,note]`，日期支持 `起..止` 区间）：
/// ```csv
/// kind,date,note
/// statutory,2027-01-01,元旦
/// makeup,2027-01-24,春节调休
/// break,2027-01-01..2027-01-03,元旦连休
/// ```
class HolidayFileService {
  const HolidayFileService._();

  static const String _bom = '\uFEFF';

  /// JSON 三类字段的别名
  static const Map<String, List<String>> _jsonKeys = <String, List<String>>{
    'statutory': <String>['statutory', 'statutoryHolidays', 'holidays', 'legal'],
    'makeup': <String>['makeup', 'makeupWorkdays', 'workdays'],
    'breaks': <String>['breaks', 'holidayBreaks', 'rests'],
  };

  /// CSV 类型列的别名
  static const Map<String, List<String>> _csvKinds = <String, List<String>>{
    'statutory': <String>['statutory', 'holiday', 'legal', '法定', '节假日'],
    'makeup': <String>['makeup', 'makeupworkday', 'workday', '补班', '调休'],
    'breaks': <String>['break', 'breaks', 'rest', '放假', '连休', '休息'],
  };

  /// 解析文本，自动识别 JSON（以 `{` / `[` 开头）与 CSV
  static HolidayParseResult parse(String rawText, {String name = ''}) {
    var text = rawText;
    if (text.startsWith(_bom)) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty) throw const FormatException('文件内容为空');

    if (text.startsWith('{') || text.startsWith('[')) {
      return _parseJson(text, fallbackName: name);
    }
    return _parseCsv(text, fallbackName: name);
  }

  /// 选择本地文件并解析，返回 null 表示用户取消了选择
  static Future<HolidayParseResult?> pickAndParse() async {
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
    return parse(text, name: picked.name);
  }

  /// 联网拉取并解析
  static Future<HolidayParseResult> download(String url) async {
    final text = await HttpService.getText(url);
    final result = parse(text, name: Uri.tryParse(url)?.pathSegments.last ?? '');
    if (result.isEmpty) {
      throw const FormatException('远程文件里没有可用的节假日数据');
    }
    return result;
  }

  /// 生成 JSON 文本（供导出与仓库数据源使用）
  static String exportToString(HolidayData data, {String name = '节假日数据'}) {
    final years = data.years.toList()..sort();
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'working_hours',
      'name': name,
      'years': years,
      'exportedAt': DateTime.now().toIso8601String(),
      'statutory': data.statutory.toList()..sort(),
      'makeup': data.makeup.toList()..sort(),
      'breaks': data.breaks.toList()..sort(),
    });
  }

  /// 导出到临时目录并调用系统分享面板
  static Future<File> exportAndShare(HolidayData data) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/记工时_节假日_$stamp.json');
    await file.writeAsString(exportToString(data), flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'application/json')],
      text: '记工时 - 节假日数据导出（覆盖年份：${data.years.join('、')}）',
    );
    return file;
  }

  // ------------------------------------------------------------------ JSON

  static HolidayParseResult _parseJson(String text, {required String fallbackName}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('不是有效的 JSON 文件');
    }

    var ignored = 0;
    var name = fallbackName;
    final statutory = <String>{};
    final makeup = <String>{};
    final breaks = <String>{};

    void addAll(String bucket, List<dynamic> items) {
      for (final item in items) {
        final spec = item?.toString() ?? '';
        final days = expandDateSpec(spec);
        if (days.isEmpty) {
          ignored++;
          continue;
        }
        switch (bucket) {
          case 'statutory':
            statutory.addAll(days);
          case 'makeup':
            makeup.addAll(days);
          default:
            breaks.addAll(days);
        }
      }
    }

    if (decoded is Map) {
      name = _text(decoded['name']) == ''
          ? (_text(decoded['title']) == '' ? fallbackName : _text(decoded['title']))
          : _text(decoded['name']);
      for (final bucket in _jsonKeys.keys) {
        final keys = _jsonKeys[bucket]!;
        for (final key in keys) {
          final value = decoded[key];
          if (value is List) addAll(bucket, value);
        }
      }
    } else if (decoded is List) {
      for (final row in decoded) {
        if (row is! Map) {
          ignored++;
          continue;
        }
        final spec = _text(row['date'] ?? row['day']);
        final days = expandDateSpec(spec);
        if (days.isEmpty) {
          ignored++;
          continue;
        }
        final bucket = _bucketOfKind(_text(row['kind'] ?? row['type']));
        if (bucket == null) {
          ignored++;
          continue;
        }
        addAll(bucket, days.toList());
      }
    } else {
      throw const FormatException('JSON 结构无法识别，需要对象或数组');
    }

    if (statutory.isEmpty && makeup.isEmpty && breaks.isEmpty) {
      throw const FormatException('JSON 中没有可用的节假日字段');
    }
    return HolidayParseResult(
      data: HolidayData(
        statutory: statutory,
        makeup: makeup,
        breaks: breaks,
      ),
      name: name,
      ignored: ignored,
    );
  }

  // ------------------------------------------------------------------ CSV

  static HolidayParseResult _parseCsv(String text, {required String fallbackName}) {
    List<List<dynamic>> convert(String eol) =>
        CsvToListConverter(shouldParseNumbers: false, eol: eol)
            .convert(text)
            .where((row) => row.any((cell) => _text(cell).isNotEmpty))
            .toList();

    var rows = convert('\r\n');
    if (rows.length < 2 && text.contains('\n')) {
      final lfRows = convert('\n');
      if (lfRows.length > rows.length) rows = lfRows;
    }
    if (rows.isEmpty) throw const FormatException('文件内容为空');

    final header = rows.first.map(_text).toList();
    final lower = header.map((cell) => cell.toLowerCase()).toList();
    if (!lower.contains('date') || !lower.contains('kind')) {
      throw const FormatException('缺少表头（需包含 kind 与 date 两列）');
    }
    final kindIndex = lower.indexOf('kind');
    final dateIndex = lower.indexOf('date');

    var ignored = 0;
    final statutory = <String>{};
    final makeup = <String>{};
    final breaks = <String>{};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      String cell(int index) =>
          index < row.length ? _text(row[index]) : '';
      final days = expandDateSpec(cell(dateIndex));
      final bucket = _bucketOfKind(cell(kindIndex));
      if (days.isEmpty || bucket == null) {
        ignored++;
        continue;
      }
      switch (bucket) {
        case 'statutory':
          statutory.addAll(days);
        case 'makeup':
          makeup.addAll(days);
        default:
          breaks.addAll(days);
      }
    }

    if (statutory.isEmpty && makeup.isEmpty && breaks.isEmpty) {
      throw const FormatException('CSV 中没有可用的节假日记录');
    }
    return HolidayParseResult(
      data: HolidayData(
        statutory: statutory,
        makeup: makeup,
        breaks: breaks,
      ),
      name: fallbackName,
      ignored: ignored,
    );
  }

  /// 别名归一到三个桶；无法识别时返回 null
  static String? _bucketOfKind(String raw) {
    final kind = raw.trim().toLowerCase();
    if (kind.isEmpty) return null;
    for (final entry in _csvKinds.entries) {
      if (entry.value.any((alias) => alias.toLowerCase() == kind)) {
        return entry.key;
      }
    }
    return null;
  }

  static String _text(dynamic value) =>
      value == null ? '' : value.toString().trim();
}
