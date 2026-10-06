import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../core/holidays.dart';

/// 节假日数据来源标记
class HolidaySources {
  /// 随 APK 发布的内置数据
  static const String builtin = 'builtin';

  /// 通过联网更新获得
  static const String download = 'download';

  /// 通过导入本地文件获得
  static const String import = 'import';

  static String labelOf(String source) {
    switch (source) {
      case download:
        return '联网更新';
      case import:
        return '导入文件';
      default:
        return '内置数据';
    }
  }
}

/// 节假日数据存储：
///
/// - 未更新过 → 使用内置数据（[HolidayData.builtin]）
/// - 联网更新 / 导入文件 → 覆盖对应年份并写入本地 Box，
///   之后 [CalendarRules] 始终读取生效中的数据
class HolidayStore {
  static Box? get _box =>
      Hive.isBoxOpen(BoxNames.holidays) ? Hive.box(BoxNames.holidays) : null;

  /// 当前数据来源
  static String source = HolidaySources.builtin;

  /// 来源说明（文件名 / 远端声明的名称）
  static String note = '';

  /// 最近一次更新时间
  static DateTime? updatedAt;

  /// 是否仍为内置数据
  static bool get isBuiltin => source == HolidaySources.builtin;

  /// 当前生效数据
  static HolidayData get data => CalendarRules.activeData;

  /// 数据覆盖年份（升序拼接，如 "2025、2026、2027"）
  static String get yearsText {
    final years = data.years.toList()..sort();
    return years.isEmpty ? '暂无' : years.join('、');
  }

  /// 启动时读取本地缓存；没有缓存时保持内置数据
  static Future<void> load() async {
    final box = _box;
    if (box == null) return;
    final cached = HolidayData.fromMap(box.get('data') as Map?);
    source = box.get('source', defaultValue: HolidaySources.builtin) as String? ??
        HolidaySources.builtin;
    note = box.get('note', defaultValue: '') as String? ?? '';
    final stamp = box.get('updatedAt') as String?;
    updatedAt = stamp == null ? null : DateTime.tryParse(stamp);
    CalendarRules.setActive(
      cached.isEmpty ? HolidayData.builtin : cached,
    );
  }

  /// 使新数据生效并写入本地
  static Future<void> apply(
    HolidayData data, {
    required String source,
    String note = '',
  }) async {
    HolidayStore.source = source;
    HolidayStore.note = note;
    HolidayStore.updatedAt = DateTime.now();
    CalendarRules.setActive(data);

    final box = _box;
    if (box == null) return;
    await box.putAll(<String, dynamic>{
      'data': data.toMap(),
      'source': source,
      'note': note,
      'updatedAt': HolidayStore.updatedAt!.toIso8601String(),
    });
  }

  /// 恢复为内置数据
  static Future<void> resetToBuiltin() async {
    source = HolidaySources.builtin;
    note = '';
    updatedAt = null;
    CalendarRules.setActive(HolidayData.builtin);

    final box = _box;
    if (box == null) return;
    await box.deleteAll(<String>['data', 'source', 'note', 'updatedAt']);
  }
}
