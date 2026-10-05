import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants.dart';
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

  runApp(const ProviderScope(child: WorkingHoursApp()));
}
