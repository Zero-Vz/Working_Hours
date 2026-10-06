import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../core/utils/time_utils.dart';
import '../data/models/app_settings.dart';
import 'records_provider.dart';

/// 应用设置
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  Box get _box => Hive.box(BoxNames.settings);

  @override
  AppSettings build() => AppSettings.read(_box);

  void _persist() {
    state.write(_box);
  }

  /// 金额相关设置变化时，按新规则重算已有记录
  void _recalc() {
    ref.read(recordsProvider.notifier).recalculateAmounts();
  }

  void setHourlyWage(double value) {
    state = state.copyWith(hourlyWage: value);
    _persist();
    _recalc();
  }

  /// 薪资录入方式：按时薪 / 按月薪（月薪 ÷ 21.75 ÷ 8）
  void setSalaryMode(String mode) {
    if (state.salaryMode == mode) return;
    state = state.copyWith(salaryMode: mode);
    _persist();
    _recalc();
  }

  void setMonthlySalary(double value) {
    state = state.copyWith(monthlySalary: value);
    _persist();
    _recalc();
  }

  /// 默认固定加班时薪
  void setFixedWage(double value) {
    state = state.copyWith(fixedWage: value);
    _persist();
    _recalc();
  }

  void setDefaultProject(String value) {
    state = state.copyWith(defaultProject: value);
    _persist();
  }

  /// 设置某加班类型的默认倍率
  void setRateFor(String type, double value) {
    switch (type) {
      case '工作日':
        state = state.copyWith(workdayRate: value);
      case '休息日':
        state = state.copyWith(restDayRate: value);
      case '节假日':
        state = state.copyWith(holidayRate: value);
      default:
        state = state.copyWith(customRate: value);
    }
    _persist();
  }

  void setDeductBreak(bool value) {
    state = state.copyWith(deductBreak: value);
    _persist();
    _recalc();
  }

  void setBreakMinutes(int value) {
    state = state.copyWith(breakMinutes: value);
    _persist();
    _recalc();
  }

  void setRoundToMinute(bool value) {
    state = state.copyWith(roundToMinute: value);
    _persist();
    _recalc();
  }

  void setThemeMode(String value) {
    state = state.copyWith(themeMode: value);
    _persist();
  }

  /// 是否将月薪计入总工资
  void setIncludeSalaryInTotal(bool value) {
    state = state.copyWith(includeSalaryInTotal: value);
    _persist();
  }

  /// 是否将月薪与固定工资项均摊到每个工作日
  void setSpreadToWorkdays(bool value) {
    state = state.copyWith(spreadToWorkdays: value);
    _persist();
  }

  /// 统计页是否展示整月总工资（含扣增）
  void setShowTotalSalary(bool value) {
    state = state.copyWith(showTotalSalary: value);
    _persist();
  }

  /// 是否显示请假记录（记录页分段与统计页请假汇总 / 趋势）
  void setShowLeaveRecords(bool value) {
    state = state.copyWith(showLeaveRecords: value);
    _persist();
  }

  /// 是否显示增扣项（统计页增扣金额卡与增扣趋势）
  void setShowIncomeItems(bool value) {
    state = state.copyWith(showIncomeItems: value);
    _persist();
  }

  /// 趋势图样式：折线图 / 条形图
  void setTrendChartStyle(String value) {
    state = state.copyWith(trendChartStyle: TrendChartStyles.normalize(value));
    _persist();
  }

  /// 四张趋势图的独立显示开关（时长 / 金额 / 增扣 / 请假）
  void setShowHoursTrend(bool value) {
    state = state.copyWith(showHoursTrend: value);
    _persist();
  }

  void setShowAmountTrend(bool value) {
    state = state.copyWith(showAmountTrend: value);
    _persist();
  }

  void setShowIncomeTrend(bool value) {
    state = state.copyWith(showIncomeTrend: value);
    _persist();
  }

  void setShowLeaveTrend(bool value) {
    state = state.copyWith(showLeaveTrend: value);
    _persist();
  }

  /// 节假日数据联网更新地址
  void setHolidayUpdateUrl(String value) {
    final trimmed = value.trim();
    state = state.copyWith(
      holidayUpdateUrl: trimmed.isEmpty ? kHolidayUpdateUrl : trimmed,
    );
    _persist();
  }

  /// 检查软件更新的接口地址
  void setReleaseApiUrl(String value) {
    final trimmed = value.trim();
    state = state.copyWith(
      releaseApiUrl: trimmed.isEmpty ? kReleaseApiUrl : trimmed,
    );
    _persist();
  }

  /// 记住新增记录的开始 / 结束时间与固定时长（下次新增直接带出）
  void rememberEntry({
    required String start,
    required String end,
    required int fixedDuration,
  }) {
    if (state.lastStartTime == start &&
        state.lastEndTime == end &&
        state.lastFixedDuration == fixedDuration) {
      return;
    }
    state = state.copyWith(
      lastStartTime: start,
      lastEndTime: end,
      lastFixedDuration: fixedDuration,
    );
    _persist();
  }

  /// 按月单独设置月薪（调薪月份）
  void setSalaryOverride(int year, int month, double value) {
    final overrides = Map<String, double>.from(state.salaryOverrides)
      ..[yearMonthKey(year, month)] = value;
    state = state.copyWith(salaryOverrides: overrides);
    _persist();
    _recalc();
  }

  /// 清除某月的月薪调整，恢复为默认月薪
  void clearSalaryOverride(int year, int month) {
    if (!state.salaryOverrides.containsKey(yearMonthKey(year, month))) return;
    final overrides = Map<String, double>.from(state.salaryOverrides)
      ..remove(yearMonthKey(year, month));
    state = state.copyWith(salaryOverrides: overrides);
    _persist();
    _recalc();
  }

  /// 导入备份中的设置（仅接受已知键，导入后按新规则重算记录）
  Future<void> applyImported(Map<String, dynamic> data) async {
    const allowed = <String>{
      'hourlyWage',
      'salaryMode',
      'monthlySalary',
      'fixedWage',
      'workdayRate',
      'restDayRate',
      'holidayRate',
      'customRate',
      'deductBreak',
      'breakMinutes',
      'roundToMinute',
      'themeMode',
      'defaultProject',
      'includeSalaryInTotal',
      'spreadToWorkdays',
      'showTotalSalary',
      'showLeaveRecords',
      'showIncomeItems',
      'salaryOverrides',
      'trendChartStyle',
      'showHoursTrend',
      'showAmountTrend',
      'showIncomeTrend',
      'showLeaveTrend',
      'holidayUpdateUrl',
      'releaseApiUrl',
    };
    final payload = <String, dynamic>{
      for (final entry in data.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
    if (payload.isEmpty) return;
    await _box.putAll(payload);
    state = AppSettings.read(_box);
    _recalc();
  }
}
