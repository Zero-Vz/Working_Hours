import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/utils/calc.dart';
import '../../core/utils/time_utils.dart';
import 'salary_range.dart';

/// 应用设置（存放在 settings Box 中，全部为本地键值）
class AppSettings {
  const AppSettings({
    this.hourlyWage = 0.0,
    this.salaryMode = SalaryModes.hourly,
    this.monthlySalary = 0.0,
    this.fixedWage = 0.0,
    this.workdayRate = 1.5,
    this.restDayRate = 2.0,
    this.holidayRate = 3.0,
    this.customRate = 1.0,
    this.deductBreak = false,
    this.breakMinutes = 30,
    this.roundToMinute = true,
    this.themeMode = 'system',
    this.defaultProject = '',
    this.includeSalaryInTotal = false,
    this.spreadToWorkdays = false,
    this.showTotalSalary = false,
    this.showLeaveRecords = true,
    this.showIncomeItems = true,
    this.lastStartTime = '18:00',
    this.lastEndTime = '21:00',
    this.lastFixedDuration = 180,
    this.salaryOverrides = const <String, double>{},
    this.salaryRanges = const <SalaryRange>[],
    this.useSalaryOverrides = false,
    this.trendChartStyle = TrendChartStyles.line,
    this.showHoursTrend = true,
    this.showAmountTrend = true,
    this.showIncomeTrend = true,
    this.showLeaveTrend = true,
    this.holidayUpdateUrl = kHolidayUpdateUrl,
    this.releaseApiUrl = kReleaseApiUrl,
  });

  /// 时薪（元 / 小时，salaryMode 为 hourly 时生效）
  final double hourlyWage;

  /// 薪资录入方式：hourly（按时薪）/ monthly（按月薪）
  final String salaryMode;

  /// 月薪（元 / 月，salaryMode 为 monthly 时生效）
  final double monthlySalary;

  /// 默认固定加班时薪（元 / 小时，新增记录按固定时薪计算时的默认值）
  final double fixedWage;

  /// 各加班类型默认倍率
  final double workdayRate;
  final double restDayRate;
  final double holidayRate;
  final double customRate;

  /// 是否扣除休息时间
  final bool deductBreak;

  /// 每条记录扣除的休息分钟数
  final int breakMinutes;

  /// 折算工时是否四舍五入到分钟
  final bool roundToMinute;

  /// system / light / dark
  final String themeMode;

  /// 默认项目名
  final String defaultProject;

  /// 是否将月薪计入总工资（统计页「整月总工资」）
  final bool includeSalaryInTotal;

  /// 是否将月薪与固定工资项均摊到整月的每个工作日（每日金额趋势）
  final bool spreadToWorkdays;

  /// 统计页是否展示「整月总工资（含扣增）」：
  /// true = 总工资卡 + 总金额趋势；false = 仅加班记录趋势
  final bool showTotalSalary;

  /// 是否显示请假记录（记录页分段、统计页请假汇总与请假趋势）
  final bool showLeaveRecords;

  /// 是否显示增扣项（统计页增扣金额卡与增扣趋势）
  final bool showIncomeItems;

  /// 新增记录默认开始 / 结束时间（记住上一次保存的值）
  final String lastStartTime;
  final String lastEndTime;

  /// 新增记录默认固定时长（分钟）
  final int lastFixedDuration;

  /// 按月单独设置的月薪（键为年月，如 2026-10；缺省月份用 [monthlySalary]）
  final Map<String, double> salaryOverrides;

  /// 生效起止日期区间（按月薪录入的默认方式，按起始日期升序）
  final List<SalaryRange> salaryRanges;

  /// 是否启用「按月单独修改月薪」（默认关闭，展开逐月列表后才生效）
  final bool useSalaryOverrides;

  /// 统计页趋势图样式：line（折线）/ bar（条形）
  final String trendChartStyle;

  /// 统计页四张趋势图的独立显示开关（时长 / 金额 / 增扣 / 请假）
  final bool showHoursTrend;
  final bool showAmountTrend;
  final bool showIncomeTrend;
  final bool showLeaveTrend;

  /// 节假日数据联网更新地址
  final String holidayUpdateUrl;

  /// 检查软件更新的接口地址（返回 GitHub Releases 风格的 JSON）
  final String releaseApiUrl;

  /// 趋势图是否用条形图显示
  bool get useBarChart => trendChartStyle == TrendChartStyles.bar;

  ThemeMode get theme {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 实际参与计算的时薪：
  /// 月薪模式下 = 月薪 ÷ 21.75 ÷ 8
  double get effectiveHourlyWage {
    if (salaryMode == SalaryModes.monthly && monthlySalary > 0) {
      return WorkCalc.hourlyFromMonthly(monthlySalary);
    }
    return hourlyWage;
  }

  /// 某日期命中的生效区间（重叠时取起始日期更晚的一段）
  SalaryRange? salaryRangeAt(DateTime date) {
    SalaryRange? best;
    for (final range in salaryRanges) {
      if (range.covers(date) && (best == null || !range.start.isBefore(best.start))) {
        best = range;
      }
    }
    return best;
  }

  /// 某日期生效的月薪（按月薪模式）：
  /// 开启按月单独修改时优先取该月调整值，其次取命中的生效区间，最后取默认月薪
  double salaryForDate(DateTime date) {
    if (useSalaryOverrides) {
      final override = salaryOverrides[yearMonthKey(date.year, date.month)];
      if (override != null) return override;
    }
    return salaryRangeAt(date)?.amount ?? monthlySalary;
  }

  /// 某年月生效的月薪（统计月度汇总使用）
  ///
  /// 区间月中开始 / 结束时，先取该月 15 日的值，再退回覆盖该月的区间。
  double salaryForYearMonth(int year, int month) {
    if (useSalaryOverrides) {
      final override = salaryOverrides[yearMonthKey(year, month)];
      if (override != null) return override;
    }
    final fromMid = salaryRangeAt(DateTime(year, month, 15));
    if (fromMid != null) return fromMid.amount;
    SalaryRange? overlapping;
    for (final range in salaryRanges) {
      if (range.overlapsMonth(year, month) &&
          (overlapping == null || !range.start.isBefore(overlapping.start))) {
        overlapping = range;
      }
    }
    return overlapping?.amount ?? monthlySalary;
  }

  /// 某日期所在月份生效的月薪
  double salaryFor(DateTime date) => salaryForYearMonth(date.year, date.month);

  /// 某日期所在月份生效的时薪（按月薪反推时会考虑该日的月薪）
  double effectiveHourlyWageFor(DateTime date) {
    if (salaryMode == SalaryModes.monthly) {
      final salary = salaryForDate(date);
      if (salary > 0) return WorkCalc.hourlyFromMonthly(salary);
      return hourlyWage;
    }
    return hourlyWage;
  }

  /// 每日金额趋势是否平摊固定金额（月薪计入总工资时自动平摊到每个工作日）
  bool get spreadDailyAmount => spreadToWorkdays || includeSalaryInTotal;

  /// 是否使用月薪反推时薪
  bool get useMonthlySalary => salaryMode == SalaryModes.monthly;

  /// 某加班类型的默认倍率
  double defaultRateOf(String type) {
    switch (type) {
      case OvertimeTypes.weekday:
        return workdayRate;
      case OvertimeTypes.restDay:
        return restDayRate;
      case OvertimeTypes.holiday:
        return holidayRate;
      default:
        return customRate;
    }
  }

  AppSettings copyWith({
    double? hourlyWage,
    String? salaryMode,
    double? monthlySalary,
    double? fixedWage,
    double? workdayRate,
    double? restDayRate,
    double? holidayRate,
    double? customRate,
    bool? deductBreak,
    int? breakMinutes,
    bool? roundToMinute,
    String? themeMode,
    String? defaultProject,
    bool? includeSalaryInTotal,
    bool? spreadToWorkdays,
    bool? showTotalSalary,
    bool? showLeaveRecords,
    bool? showIncomeItems,
    String? lastStartTime,
    String? lastEndTime,
    int? lastFixedDuration,
    Map<String, double>? salaryOverrides,
    List<SalaryRange>? salaryRanges,
    bool? useSalaryOverrides,
    String? trendChartStyle,
    bool? showHoursTrend,
    bool? showAmountTrend,
    bool? showIncomeTrend,
    bool? showLeaveTrend,
    String? holidayUpdateUrl,
    String? releaseApiUrl,
  }) {
    return AppSettings(
      hourlyWage: hourlyWage ?? this.hourlyWage,
      salaryMode: salaryMode ?? this.salaryMode,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      fixedWage: fixedWage ?? this.fixedWage,
      workdayRate: workdayRate ?? this.workdayRate,
      restDayRate: restDayRate ?? this.restDayRate,
      holidayRate: holidayRate ?? this.holidayRate,
      customRate: customRate ?? this.customRate,
      deductBreak: deductBreak ?? this.deductBreak,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      roundToMinute: roundToMinute ?? this.roundToMinute,
      themeMode: themeMode ?? this.themeMode,
      defaultProject: defaultProject ?? this.defaultProject,
      includeSalaryInTotal: includeSalaryInTotal ?? this.includeSalaryInTotal,
      spreadToWorkdays: spreadToWorkdays ?? this.spreadToWorkdays,
      showTotalSalary: showTotalSalary ?? this.showTotalSalary,
      showLeaveRecords: showLeaveRecords ?? this.showLeaveRecords,
      showIncomeItems: showIncomeItems ?? this.showIncomeItems,
      lastStartTime: lastStartTime ?? this.lastStartTime,
      lastEndTime: lastEndTime ?? this.lastEndTime,
      lastFixedDuration: lastFixedDuration ?? this.lastFixedDuration,
      salaryOverrides: salaryOverrides ?? this.salaryOverrides,
      salaryRanges: salaryRanges ?? this.salaryRanges,
      useSalaryOverrides: useSalaryOverrides ?? this.useSalaryOverrides,
      trendChartStyle: trendChartStyle ?? this.trendChartStyle,
      showHoursTrend: showHoursTrend ?? this.showHoursTrend,
      showAmountTrend: showAmountTrend ?? this.showAmountTrend,
      showIncomeTrend: showIncomeTrend ?? this.showIncomeTrend,
      showLeaveTrend: showLeaveTrend ?? this.showLeaveTrend,
      holidayUpdateUrl: holidayUpdateUrl ?? this.holidayUpdateUrl,
      releaseApiUrl: releaseApiUrl ?? this.releaseApiUrl,
    );
  }

  /// 从本地 Box 读取（缺失键使用默认值）
  factory AppSettings.read(Box box) {
    double number(String key, double fallback) =>
        (box.get(key, defaultValue: fallback) as num?)?.toDouble() ?? fallback;
    int integer(String key, int fallback) =>
        (box.get(key, defaultValue: fallback) as num?)?.toInt() ?? fallback;
    bool flag(String key, {bool fallback = false}) =>
        box.get(key, defaultValue: fallback) as bool? ?? fallback;
    String text(String key, String fallback) =>
        box.get(key, defaultValue: fallback) as String? ?? fallback;

    final rawOverrides = box.get('salaryOverrides');
    final overrides = <String, double>{};
    if (rawOverrides is Map) {
      rawOverrides.forEach((key, value) {
        final amount = (value as num?)?.toDouble();
        if (key is String && amount != null) overrides[key] = amount;
      });
    }

    final ranges = <SalaryRange>[];
    final rawRanges = box.get('salaryRanges');
    if (rawRanges is List) {
      for (final item in rawRanges) {
        final range = SalaryRange.fromMap(item);
        if (range != null) ranges.add(range);
      }
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));

    // 地址类设置：清空时回退到默认地址
    String url(String key, String fallback) {
      final value = box.get(key, defaultValue: fallback) as String? ?? '';
      return value.trim().isEmpty ? fallback : value.trim();
    }

    return AppSettings(
      hourlyWage: number('hourlyWage', 0),
      salaryMode:
          SalaryModes.normalize(box.get('salaryMode') as String?),
      monthlySalary: number('monthlySalary', 0),
      fixedWage: number('fixedWage', 0),
      workdayRate: number('workdayRate', 1.5),
      restDayRate: number('restDayRate', 2),
      holidayRate: number('holidayRate', 3),
      customRate: number('customRate', 1),
      deductBreak: box.get('deductBreak', defaultValue: false) as bool? ?? false,
      breakMinutes: integer('breakMinutes', 30),
      roundToMinute: box.get('roundToMinute', defaultValue: true) as bool? ?? true,
      themeMode:
          box.get('themeMode', defaultValue: 'system') as String? ?? 'system',
      defaultProject: box.get('defaultProject', defaultValue: '') as String? ?? '',
      includeSalaryInTotal: flag('includeSalaryInTotal'),
      spreadToWorkdays: flag('spreadToWorkdays'),
      showTotalSalary: flag('showTotalSalary'),
      showLeaveRecords: flag('showLeaveRecords', fallback: true),
      showIncomeItems: flag('showIncomeItems', fallback: true),
      lastStartTime: text('lastStartTime', '18:00'),
      lastEndTime: text('lastEndTime', '21:00'),
      lastFixedDuration: integer('lastFixedDuration', 180),
      salaryOverrides: overrides,
      salaryRanges: ranges,
      useSalaryOverrides: flag('useSalaryOverrides'),
      trendChartStyle: TrendChartStyles.normalize(
        box.get('trendChartStyle') as String?,
      ),
      showHoursTrend: flag('showHoursTrend', fallback: true),
      showAmountTrend: flag('showAmountTrend', fallback: true),
      showIncomeTrend: flag('showIncomeTrend', fallback: true),
      showLeaveTrend: flag('showLeaveTrend', fallback: true),
      holidayUpdateUrl: url('holidayUpdateUrl', kHolidayUpdateUrl),
      releaseApiUrl: url('releaseApiUrl', kReleaseApiUrl),
    );
  }

  /// 导出为键值（键与 Box 一致，供全量备份使用）
  Map<String, dynamic> toMap() => <String, dynamic>{
        'hourlyWage': hourlyWage,
        'salaryMode': salaryMode,
        'monthlySalary': monthlySalary,
        'fixedWage': fixedWage,
        'workdayRate': workdayRate,
        'restDayRate': restDayRate,
        'holidayRate': holidayRate,
        'customRate': customRate,
        'deductBreak': deductBreak,
        'breakMinutes': breakMinutes,
        'roundToMinute': roundToMinute,
        'themeMode': themeMode,
        'defaultProject': defaultProject,
        'includeSalaryInTotal': includeSalaryInTotal,
        'spreadToWorkdays': spreadToWorkdays,
        'showTotalSalary': showTotalSalary,
        'showLeaveRecords': showLeaveRecords,
        'showIncomeItems': showIncomeItems,
        'lastStartTime': lastStartTime,
        'lastEndTime': lastEndTime,
        'lastFixedDuration': lastFixedDuration,
        'salaryOverrides': salaryOverrides,
        'salaryRanges': [for (final range in salaryRanges) range.toMap()],
        'useSalaryOverrides': useSalaryOverrides,
        'trendChartStyle': trendChartStyle,
        'showHoursTrend': showHoursTrend,
        'showAmountTrend': showAmountTrend,
        'showIncomeTrend': showIncomeTrend,
        'showLeaveTrend': showLeaveTrend,
        'holidayUpdateUrl': holidayUpdateUrl,
        'releaseApiUrl': releaseApiUrl,
      };

  /// 写入本地 Box
  Future<void> write(Box box) => box.putAll(toMap());
}
