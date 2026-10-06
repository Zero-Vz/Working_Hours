import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants.dart';
import 'data/holiday_store.dart';
import 'data/models/income_item.dart';
import 'data/models/leave_record.dart';
import 'data/models/overtime_record.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(OvertimeRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(LeaveRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(IncomeItemAdapter());
  }

  await Hive.openBox<OvertimeRecord>(BoxNames.records);
  await Hive.openBox<LeaveRecord>(BoxNames.leaves);
  await Hive.openBox<IncomeItem>(BoxNames.incomeItems);
  await Hive.openBox(BoxNames.settings);
  await Hive.openBox(BoxNames.holidays);

  // 恢复联网更新 / 导入的节假日数据（没有则保持内置数据）
  await HolidayStore.load();

  runApp(const ProviderScope(child: WorkingHoursApp()));
}
