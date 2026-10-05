import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
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
}
