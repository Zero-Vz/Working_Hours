import 'package:flutter/material.dart';

/// 本地数据库 Box 名称
class BoxNames {
  static const String records = 'records';
  static const String settings = 'settings';
  static const String leaves = 'leaves';
  static const String incomeItems = 'incomeItems';

  /// 节假日日历（联网更新 / 文件导入后的数据，缺省为内置数据）
  static const String holidays = 'holidays';
}

/// 记录页展示的记录大类
class RecordKinds {
  static const String overtime = 'overtime';
  static const String leave = 'leave';

  static const List<String> all = [overtime, leave];

  static String labelOf(String kind) => kind == leave ? '请假记录' : '加班记录';
}

/// 请假类型：带薪 / 无薪
class LeaveTypes {
  /// 请假类型：带薪 / 无薪
  static const String paid = 'paid';

  /// 无薪：按填写金额扣工资
  static const String unpaid = 'unpaid';

  static const List<String> all = [paid, unpaid];

  static String labelOf(String? type) => type == unpaid ? '无薪' : '带薪';

  static bool isPaid(String? type) => type != unpaid;

  static IconData iconOf(String? type) =>
      type == unpaid ? Icons.beach_access_outlined : Icons.payments_outlined;

  static Color colorOf(String? type) =>
      type == unpaid ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
}

/// 工资项类型：增项（补贴 / 绩效…）与扣项（税费 / 保险…）
class IncomeKinds {
  static const String income = 'income';
  static const String deduct = 'deduct';

  static const List<String> all = [income, deduct];

  static String labelOf(String kind) => kind == deduct ? '扣项' : '增项';

  static String hintOf(String kind) =>
      kind == deduct ? '个税、社保、公积金…' : '补贴、绩效、奖金…';

  static IconData iconOf(String kind) => kind == deduct
      ? Icons.remove_circle_outline
      : Icons.add_circle_outline;

  static Color colorOf(String kind) =>
      kind == deduct ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
}

/// 加班类型及其内置默认倍率
class OvertimeTypes {
  static const String weekday = '工作日';
  static const String restDay = '休息日';
  static const String holiday = '节假日';
  static const String custom = '自定义';

  /// 全部加班类型（顺序即展示顺序）
  static const List<String> all = [weekday, restDay, holiday, custom];

  /// 内置默认倍率（可在设置页修改）
  static const Map<String, double> builtinRates = <String, double>{
    weekday: 1.5,
    restDay: 2.0,
    holiday: 3.0,
    custom: 1.0,
  };

  static double builtinRateOf(String type) => builtinRates[type] ?? 1.0;

  static IconData iconOf(String type) {
    switch (type) {
      case weekday:
        return Icons.work_outline;
      case restDay:
        return Icons.weekend_outlined;
      case holiday:
        return Icons.celebration_outlined;
      default:
        return Icons.tune_outlined;
    }
  }

  static Color colorOf(String type) {
    switch (type) {
      case weekday:
        return const Color(0xFF3F51B5);
      case restDay:
        return const Color(0xFF00897B);
      case holiday:
        return const Color(0xFFD84315);
      default:
        return const Color(0xFF6D4C41);
    }
  }
}

/// 单条记录的计算方式
///
/// - [rate]：按倍率，金额 = 有效时长 × 倍率 × 时薪
/// - [fixed]：按固定加班时薪，金额 = 有效时长 × 固定加班时薪
class CalcModes {
  static const String rate = 'rate';
  static const String fixed = 'fixed';

  static const List<String> all = [rate, fixed];

  static String labelOf(String mode) => mode == fixed ? '固定时薪' : '按倍率';

  static String normalize(String? value) =>
      value == fixed ? fixed : rate;
}

/// 薪资录入方式（用于反推时薪）
class SalaryModes {
  /// 直接填写时薪
  static const String hourly = 'hourly';

  /// 填写月薪，时薪 = 月薪 ÷ 21.75 ÷ 8
  static const String monthly = 'monthly';

  static const List<String> all = [hourly, monthly];

  static String normalize(String? value) => value == monthly ? monthly : hourly;
}

/// 记录休息时长取值：跟随设置
const int kFollowSettingsBreak = -1;

/// 月计薪天数（人社部规定的月平均工作日）
const double kMonthlyPayDays = 21.75;

/// 每日标准工作小时数
const double kDailyWorkHours = 8.0;

/// 应用版本号（关于页展示）
const String kAppVersion = '1.5.0';

/// 统计页趋势图的显示样式
class TrendChartStyles {
  /// 折线图
  static const String line = 'line';

  /// 条形图
  static const String bar = 'bar';

  static String normalize(String? value) => value == bar ? bar : line;
}

/// 项目主页（GitHub 仓库）
const String kRepoUrl = 'https://github.com/Zero-Vz/Working_Hours';

/// 开发者主页
const String kDeveloperUrl = 'https://github.com/Zero-Vz';

/// 开发者名称
const String kDeveloperName = 'Zero-Vz';

/// 节假日数据默认更新地址（仓库内的 JSON，随发布随时可更新）
const String kHolidayUpdateUrl =
    'https://raw.githubusercontent.com/Zero-Vz/Working_Hours/main/'
    'assets/holidays/holidays.json';

/// 检查软件更新的默认地址（GitHub Releases API）
const String kReleaseApiUrl =
    'https://api.github.com/repos/Zero-Vz/Working_Hours/releases/latest';

/// 版本发布页
const String kReleasesPageUrl =
    'https://github.com/Zero-Vz/Working_Hours/releases';
