import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/time_utils.dart';
import 'models/income_item.dart';
import 'models/leave_record.dart';
import 'models/overtime_record.dart';

/// 全量备份内容（加班 + 请假 + 工资项 + 设置）
class BackupData {
  const BackupData({
    required this.records,
    required this.leaves,
    required this.incomeItems,
    required this.settings,
  });

  final List<OvertimeRecord> records;
  final List<LeaveRecord> leaves;
  final List<IncomeItem> incomeItems;

  /// 备份中的设置键值（可能为空，表示不覆盖当前设置）
  final Map<String, dynamic> settings;
}

/// JSON 全量备份 / 恢复（全部本地完成，不联网）
class BackupService {
  const BackupService._();

  static const String backupApp = 'working_hours';

  /// UTF-8 BOM，方便部分工具识别
  static const String _bom = '\uFEFF';

  /// 组装备份内容
  static Map<String, dynamic> build({
    required List<OvertimeRecord> records,
    required List<LeaveRecord> leaves,
    required List<IncomeItem> incomeItems,
    required Map<String, dynamic> settings,
  }) {
    return <String, dynamic>{
      'app': backupApp,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': <String, dynamic>{
        'records': records.length,
        'leaves': leaves.length,
        'incomeItems': incomeItems.length,
      },
      'settings': settings,
      'records': [for (final record in records) _recordToJson(record)],
      'leaves': [for (final leave in leaves) _leaveToJson(leave)],
      'incomeItems': [for (final item in incomeItems) _itemToJson(item)],
    };
  }

  /// 生成 JSON 文本
  static String encode(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  /// 导出到临时目录并调用系统分享面板
  static Future<File> exportAndShare({
    required List<OvertimeRecord> records,
    required List<LeaveRecord> leaves,
    required List<IncomeItem> incomeItems,
    required Map<String, dynamic> settings,
  }) async {
    final content = _bom +
        encode(
          build(
            records: records,
            leaves: leaves,
            incomeItems: incomeItems,
            settings: settings,
          ),
        );
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/记工时_全部数据_$stamp.json');
    await file.writeAsString(content, flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'application/json')],
      text: '记工时 - 全部数据备份'
          '（加班 ${records.length}、请假 ${leaves.length}、'
          '工资项 ${incomeItems.length}）',
    );
    return file;
  }

  /// 选择本地 JSON 并解析，返回 null 表示用户取消了选择
  static Future<BackupData?> pickAndParse() async {
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

  /// 解析备份 JSON
  static BackupData parse(String rawText) {
    var text = rawText;
    if (text.startsWith(_bom)) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty) throw const FormatException('文件内容为空');

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('不是有效的 JSON 备份文件');
    }
    if (decoded is! Map) {
      throw const FormatException('不是有效的 JSON 备份文件');
    }
    final map = Map<String, dynamic>.from(decoded);

    return BackupData(
      records: _recordsFrom(map['records']),
      leaves: _leavesFrom(map['leaves']),
      incomeItems: _itemsFrom(map['incomeItems']),
      settings: map['settings'] is Map
          ? Map<String, dynamic>.from(map['settings'] as Map)
          : const <String, dynamic>{},
    );
  }

  // ---------------------------------------------------------------- 序列化

  static Map<String, dynamic> _recordToJson(OvertimeRecord record) =>
      <String, dynamic>{
        'id': record.id,
        'date': formatDateKey(record.date),
        'startTime': record.startTime,
        'endTime': record.endTime,
        'durationMinutes': record.durationMinutes,
        'type': record.type,
        'rate': record.rate,
        'calcMode': record.calcMode,
        'fixedWage': record.fixedWage,
        'breakMinutes': record.breakMinutes,
        'project': record.project,
        'note': record.note,
        'isCompensatory': record.isCompensatory,
        'isSettled': record.isSettled,
        'amount': record.amount,
        'createdAt': record.createdAt.toIso8601String(),
        'updatedAt': record.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _leaveToJson(LeaveRecord leave) =>
      <String, dynamic>{
        'id': leave.id,
        'date': formatDateKey(leave.date),
        'days': leave.days,
        'type': leave.type,
        'reason': leave.reason,
        'deductAmount': leave.deductAmount,
        'createdAt': leave.createdAt.toIso8601String(),
        'updatedAt': leave.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _itemToJson(IncomeItem item) =>
      <String, dynamic>{
        'id': item.id,
        'name': item.name,
        'kind': item.kind,
        'amount': item.amount,
        'active': item.active,
        'monthlyOverrides': item.monthlyOverrides,
        'createdAt': item.createdAt.toIso8601String(),
        'updatedAt': item.updatedAt.toIso8601String(),
      };

  // ---------------------------------------------------------------- 反序列化

  static List<dynamic> _asList(dynamic value) =>
      value is List ? value : const [];

  static List<OvertimeRecord> _recordsFrom(dynamic value) {
    final now = DateTime.now();
    final result = <OvertimeRecord>[];
    for (final entry in _asList(value)) {
      if (entry is! Map) continue;
      final date = DateTime.tryParse(_text(entry['date']));
      if (date == null) continue;
      result.add(
        OvertimeRecord(
          id: _int(entry['id']),
          date: dateOnly(date),
          startTime: _text(entry['startTime'], '00:00'),
          endTime: _text(entry['endTime'], '00:00'),
          durationMinutes: _int(entry['durationMinutes']),
          type: _text(entry['type']),
          rate: _double(entry['rate'], 1),
          calcMode: _text(entry['calcMode'], 'rate'),
          fixedWage: _double(entry['fixedWage']),
          breakMinutes: _int(entry['breakMinutes'], -1),
          project: _text(entry['project']),
          note: _text(entry['note']),
          isCompensatory: entry['isCompensatory'] == true,
          isSettled: entry['isSettled'] == true,
          amount: _double(entry['amount']),
          createdAt: DateTime.tryParse(_text(entry['createdAt'])) ?? now,
          updatedAt: DateTime.tryParse(_text(entry['updatedAt'])) ?? now,
        ),
      );
    }
    return result;
  }

  static List<LeaveRecord> _leavesFrom(dynamic value) {
    final now = DateTime.now();
    final result = <LeaveRecord>[];
    for (final entry in _asList(value)) {
      if (entry is! Map) continue;
      final date = DateTime.tryParse(_text(entry['date']));
      if (date == null) continue;
      final type = _text(entry['type'], 'paid');
      result.add(
        LeaveRecord(
          id: _int(entry['id']),
          date: dateOnly(date),
          days: _double(entry['days'], 1),
          type: type == 'unpaid' || type == '无薪' ? 'unpaid' : 'paid',
          reason: _text(entry['reason']),
          deductAmount: _double(entry['deductAmount']),
          createdAt: DateTime.tryParse(_text(entry['createdAt'])) ?? now,
          updatedAt: DateTime.tryParse(_text(entry['updatedAt'])) ?? now,
        ),
      );
    }
    return result;
  }

  static List<IncomeItem> _itemsFrom(dynamic value) {
    final now = DateTime.now();
    final result = <IncomeItem>[];
    for (final entry in _asList(value)) {
      if (entry is! Map) continue;
      final name = _text(entry['name']);
      if (name.isEmpty) continue;
      final overrides = <String, double>{};
      final rawOverrides = entry['monthlyOverrides'];
      if (rawOverrides is Map) {
        rawOverrides.forEach((key, value) {
          final amount = (value as num?)?.toDouble();
          if (key is String && amount != null) overrides[key] = amount;
        });
      }
      result.add(
        IncomeItem(
          id: _int(entry['id']),
          name: name,
          kind: _text(entry['kind'], 'income') == 'deduct' ? 'deduct' : 'income',
          amount: _double(entry['amount']),
          active: entry['active'] != false,
          monthlyOverrides: overrides,
          createdAt: DateTime.tryParse(_text(entry['createdAt'])) ?? now,
          updatedAt: DateTime.tryParse(_text(entry['updatedAt'])) ?? now,
        ),
      );
    }
    return result;
  }

  static String _text(dynamic value, [String fallback = '']) =>
      value == null ? fallback : value.toString();

  static int _int(dynamic value, [int fallback = 0]) =>
      (value as num?)?.toInt() ?? fallback;

  static double _double(dynamic value, [double fallback = 0]) =>
      (value as num?)?.toDouble() ?? fallback;
}
